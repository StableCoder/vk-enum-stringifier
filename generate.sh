#!/usr/bin/env sh
set -e

# Variables
START=72
END=

help_blurb() {
    echo " -s, --start <INT> The starting version of Vulkan to generate for (default: 72)"
    echo " -e, --end <INT>   The ending version of Vulkan to generate for (default: none)"
}

# Command-line parsing
while [[ $# -gt 0 ]]; do
    key="$1"

    case $key in
    -s | --start)
        START="$2"
        shift # past argument
        shift # past value
        ;;
    -e | --end)
        END="$2"
        shift
        shift
        ;;
    -h | --help)
        help_blurb
        exit 0
        ;;
    esac
done

# Check for missing executables
if [ ! -x VkValueSerialization ]; then
    printf " >> Error: Could not find 'VkValueSerialization' executable\n"
elif [ ! -x VkEqualityCheck ]; then
    printf " >> Error: Could not find 'VkEqualityCheck' executable\n"
fi

# Clone/update the Vulkan-Docs repository
if ! [ -d Vulkan-Docs ]; then
    git clone https://github.com/KhronosGroup/Vulkan-Docs
fi
cd Vulkan-Docs
git fetch -p

# Prepare the top-level headers
mkdir -p ../include/vk_mini_libs_detail/
cat ../scripts/equality_check_start.txt >../include/vk_equality_checks.hpp
cat ../scripts/vulkan_string_parsing_start.txt >../include/vk_value_serialization.hpp

# Generate the per-version files
for TAG in $(git tag | grep -e "^v[0-9]*\.[0-9]*\.[0-9]*$" | sort -t '.' -k3nr); do
    VER=$(echo $TAG | cut -d'.' -f3)
    if [[ $VER -lt $START ]]; then
        # Prior to v72, vk.xml was not published, so that's the default minimum.
        break
    elif [ "$END" != "" ] && [[ $VER -gt $END ]]; then
        continue
    fi
    git checkout $TAG

    # Generate value serialization
    ../VkValueSerialization -i xml/vk.xml -d ../include/vk_mini_libs_detail/ -o vk_value_serialization_v$VER.hpp

    cat >>../include/vk_value_serialization.hpp <<EOL
#if VK_HEADER_VERSION == ${VER}
    #include "vk_mini_libs_detail/vk_value_serialization_v${VER}.hpp"
#endif
EOL

    # Generate equality checks
    ../VkEqualityCheck -i xml/vk.xml -d ../include/vk_mini_libs_detail/ -o vk_equality_checks_v$VER.hpp

    cat >>../include/vk_equality_checks.hpp <<EOL
#if VK_HEADER_VERSION == ${VER}
    #include "vk_mini_libs_detail/vk_equality_checks_v${VER}.hpp"
#endif
EOL

done

# Complete the top-level headers
cat ../scripts/equality_check_end.txt >>../include/vk_equality_checks.hpp
cat ../scripts/vulkan_string_parsing_end.txt >>../include/vk_value_serialization.hpp