set -x

usage() {
	echo $(
		printf 'Usage: %s -o its_file -s script_file -m json_metadata
		-k hlos -r rootfs -p ptgen' $(basename $0) | xargs)

	printf "\n\t-o ==> create output file 'its_file'"
	printf "\n\t-s ==> script file to be included in the FIT image"
	printf "\n\t-m ==> metadata (as string) to be included in the FIT image"
	printf "\n\t-k ==> HLOS file to be included in the FIT image"
	printf "\n\t-r ==> rootfs file to be included in the FIT image"
	printf "\n\t-p ==> path to ptgen binary for GPT generation\n"
	exit 1
}


while getopts ":o:s:m:k:r:p:" OPTION
do
	case $OPTION in
		o ) OUTPUT=$OPTARG;;
		s ) SCRIPT=$OPTARG;;
		m ) METADATA="$OPTARG";;
		k ) HLOS=$OPTARG;;
		r ) ROOTFS=$OPTARG;;
		p ) PTGEN=$OPTARG;;
		* ) echo "Invalid option passed to '$0' (options:$*)"
		usage;;
	esac
done

# Make sure user entered all required parameters
if [ -z "${OUTPUT}" ] || [ -z "${SCRIPT}" ] || [ -z "${METADATA}" ] || [ -z "${HLOS}" ] || [ -z "${PTGEN}" ]; then
	usage
fi

# Prepare tmpdir	
TMPDIR=$(mktemp -d 2>/dev/null)
trap "rm -rf $TMPDIR" EXIT

# Generate OEM-compatible GPT: 3 partitions starting at LBA 34, no alignment gap
${PTGEN} -g -o ${TMPDIR}/gpt.bin -a 1 \
	-t 0x2e -N 0:HLOS -r -p 32M \
	-t 0x83 -N rootfs -r -p 128M \
	-N rootfs_data -p 512M

# Compute block counts (ceil(filesize / 512)) in hex for U-Boot mmc write commands
GPT_BLKCNT=$(printf '%x' $(( ($(stat -c%s "${TMPDIR}/gpt.bin") + 511) / 512 )))
HLOS_BLKCNT=$(printf '%x' $(( ($(stat -c%s "${HLOS}") + 511) / 512 )))
ROOTFS_BLKCNT=$(printf '%x' $(( ($(stat -c%s "${ROOTFS}") + 511) / 512 )))
ROOTFS_DATA_BLKCNT=1

# Substitute build-time placeholders in the script file
cp "${SCRIPT}" "${TMPDIR}/script.uboot"
sed -i \
    -e "s/__GPT_BLKCNT__/${GPT_BLKCNT}/g" \
    -e "s/__HLOS_BLKCNT__/${HLOS_BLKCNT}/g" \
    -e "s/__ROOTFS_BLKCNT__/${ROOTFS_BLKCNT}/g" \
    -e "s/__ROOTFS_DATA_BLKCNT__/${ROOTFS_DATA_BLKCNT}/g" \
    "${TMPDIR}/script.uboot"

# Minify into one semicolon-joined line for the embedded U-Boot script.
SCRIPT_NAME=$(basename ${SCRIPT})
python3 -c '
import re, sys

with open(sys.argv[1]) as src, open(sys.argv[2], "w") as dst:
	file = ""
	for line in src:
		result = ""  # dropped if outside quoted strings
		in_single = False
		in_double = False
		i = 0
		while i < len(line):
			c = line[i]
			if c == "\\" and i + 1 < len(line):
				result += c + line[i + 1]
				i += 2
				continue
			if c == "\x27" and not in_double:
				in_single = not in_single
			elif c == "\x22" and not in_single:
				in_double = not in_double
			elif c == "#" and not in_single and not in_double:
				break
			result += c
			i += 1
		line = result
		line = re.sub(r"\s+", " ", line)
		line = line.strip()
		line = re.sub(r"\s*;\s*", ";", line)
		line = re.sub(r"\s*&&\s*", "&&", line)
		line = re.sub(r"\s*\|\|\s*", "||", line)
		line = line + ";"

		file += line
	file = re.sub(r"\s+", " ", file)
	file = re.sub(r";+", ";", file)
	file = re.sub(r"^;+|;+$", "", file)
	file = re.sub(r"\s*;\s*", ";", file)
	file = file.strip()
	dst.write(file)
' "${TMPDIR}/script.uboot" "${TMPDIR}/script.tmp"

# Metadata goes straight into a variable -- no file needed.
echo "${METADATA}" |\
 python3 -c 'import json, sys; print(json.dumps(json.load(sys.stdin)))' > ${TMPDIR}/metadata.tmp

# Create padded rootfs_data marker (512 bytes = 1 eMMC block) as inline hex.
# Do not reference TMPDIR files in ITS because mkimage runs after this script exits.
ROOTFS_DATA_HEX="de ad c0 de"
ROOTFS_DATA_PAD=$(yes "00" | head -n 508 | xargs)
GPT_HEX=$(hexdump -v -e '1/1 "%02x "' ${TMPDIR}/gpt.bin | xargs)

HLOS_NAME=$(basename ${HLOS})
ROOTFS_NAME=$(basename ${ROOTFS})



# FIT tree mirrors the OEM firmware's exact structure.
cat> ${OUTPUT} << EOI
/dts-v1/;

/ {
	description = "Flashing emmc 200 200";

	images {
		script {
			description = "${SCRIPT_NAME}";
			data = [$(hexdump -v -e '1/1 "%02x "' ${TMPDIR}/script.tmp | xargs)];
			type = "script";
			arch = "arm";
			compression = "none";

			hash@1 {
				algo = "crc32";
			};
		};
		sysupgrade.meta {
			description = "sysupgrade.meta";
			data = [$(hexdump -v -e '1/1 "%02x "' ${TMPDIR}/metadata.tmp | xargs)];
			type = "standalone";
			arch = "arm";
			compression = "none";

			hash@1 {
				algo = "crc32";
			};
		};
		hlos {
			description = "${HLOS_NAME}";
			data = /incbin/("${HLOS}");
			type = "firmware";
			arch = "arm";
			compression = "none";

			hash@1 {
				algo = "crc32";
			};
		};
		rootfs {
			description = "${ROOTFS_NAME}";
			data = /incbin/("${ROOTFS}");
			type = "firmware";
			arch = "arm";
			compression = "none";

			hash@1 {
				algo = "crc32";
			};
		};
		rootfs_data {
			description = "rootfs_data";
			data = [${ROOTFS_DATA_HEX} ${ROOTFS_DATA_PAD}];
			type = "firmware";
			arch = "arm";
			compression = "none";

			hash@1 {
				algo = "crc32";
			};
		};
		gpt {
			description = "gpt";
			data = [${GPT_HEX}];
			type = "firmware";
			arch = "arm";
			compression = "none";

			hash@1 {
				algo = "crc32";
			};
		};
	};
};
EOI
