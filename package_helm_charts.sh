#!/bin/bash

INPUTS_CHARTS_DIR=${1};
INPUTS_BUILD_DIR=${2};
INPUTS_BRANCH_TAG_RULES=${3};

declare -A GLOBAL_BRANCH_TAG_RULES_MAP;
declare -A GLOBAL_CHARTS_VERSION_MAP;
declare -A GLOBAL_CHARTS_STATUS_MAP;

function parse_branch_tag_rules() {

    IFS=',' read -r -a pairs <<< "${INPUTS_BRANCH_TAG_RULES}";

    for pair in "${pairs[@]}"; do

        IFS=':' read -r key value <<< "${pair}";
        GLOBAL_BRANCH_TAG_RULES_MAP["${key}"]="${value}";

    done

}

function package_single_chart() {

    local chart_dir=${1};
    
    local chart_name=` helm show chart ${chart_dir} | grep name | sed 's/name: //' `;
    local chart_version=` helm show chart ${chart_dir} | grep version | sed 's/version: //' `;

    local git_branch=` git rev-parse --abbrev-ref HEAD `;

    local branch_tag_rule=${GLOBAL_BRANCH_TAG_RULES_MAP[${git_branch}]};

    echo "Packaging chart '${chart_name}' with version '${chart_version}'...";

    if echo "${chart_version}" | grep -Eq "${branch_tag_rule}"; then
        
        if helm package "${chart_dir}" -d ${INPUTS_BUILD_DIR}; then

            echo "SUCCESS: Chart packaged";
            GLOBAL_CHARTS_VERSION_MAP["${chart_dir}"]="${chart_version}";
            GLOBAL_CHARTS_STATUS_MAP["${chart_dir}"]="success";

        else

            echo "ERROR: Failed to package chart";
            GLOBAL_CHARTS_VERSION_MAP["${chart_dir}"]="${chart_version}";
            GLOBAL_CHARTS_STATUS_MAP["${chart_dir}"]="failed";

        fi

    else

        echo "ERROR: Chart version does not satisfy '${git_branch}' branch naming constraints REGEX( ${branch_tag_rule} ), skipping packaging";
        return 1;

    fi

}

function main() {

    parse_branch_tag_rules
    
    for DIR in ` find . -maxdepth 2 -type d -regex "./${INPUTS_CHARTS_DIR}/.*" `; do

        package_single_chart ${DIR};

    done

}

main;