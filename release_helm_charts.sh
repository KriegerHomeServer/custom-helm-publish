#!/bin/bash

INPUTS_MARK_LATEST=${1};
INPUTS_BUILD_DIR=${2};
INPUTS_PACKAGES_DIR=${3};

function release_single_chart() {

    local chart_file=${1};

    local action="none";

    local chart_name=` helm show chart ${chart_file} | grep name | sed 's/name: //' `;
    local chart_description=` helm show chart ${chart_file} | grep description | sed 's/description: //' `;
    local chart_version=` helm show chart ${chart_file} | grep version | sed 's/version: //' `;

    local existing_chart_file="${INPUTS_PACKAGES_DIR}/${chart_name}-${chart_version}.tgz";

    if [ ! -f "${existing_chart_file}" ]; then

        mv ${chart_file} ${INPUTS_PACKAGES_DIR};
        action="create";

    else

        local current_sha256sum=` sha256sum ${chart_file} | awk '{ print $1 }' `;
        local existing_sha256sum=` sha256sum ${existing_chart_file} | awk '{ print $1 }' `;

        if [ "${current_sha256sum}" != "${existing_sha256sum}" ]; then

            mv ${chart_file} ${INPUTS_PACKAGES_DIR};
            action="update";

        fi

    fi

    case "${action}" in

        "create")
            echo "Creating release for chart '${chart_name}' version '${chart_version}'...";

            if [ "${INPUTS_MARK_LATEST}" == "true" ]; then
                
                gh release create "${chart_name}-${chart_version}" "${existing_chart_file}" --notes "${chart_description}" --latest;

            else

                gh release create "${chart_name}-${chart_version}" "${existing_chart_file}" --notes "${chart_description}" --prerelease;

            fi
            ;;

        "update")
            echo "Updating release for chart '${current_chart_name}' version '${current_chart_version}'...";

            if ! gh release view "${chart_name}-${chart_version}"; then

                if [ "${INPUTS_MARK_LATEST}" == "true" ]; then
                
                    gh release create "${chart_name}-${chart_version}" "${existing_chart_file}" --notes "${chart_description}" --latest;

                else

                    gh release create "${chart_name}-${chart_version}" "${existing_chart_file}" --notes "${chart_description}" --prerelease;

                fi

            else

                gh release edit "${chart_name}-${chart_version}" --notes "${chart_description}"

                gh release upload "${chart_name}-${chart_version}" "${existing_chart_file}" --clobber;

            fi
            ;;

        "none")
            echo "No action required for chart '${current_chart_name}' version '${current_chart_version}'...";
            ;;

    esac

}

function update_index() {
    
    helm repo index ${INPUTS_PACKAGES_DIR};

    yq 'with(.entries.*.[]; .urls = ["https://github.com/KriegerHomeServer/helm-charts-development/releases/download/" + .name + "-" + .version + "/" + .name + "-" + .version + ".tgz"])' "${INPUTS_PACKAGES_DIR}/index.yaml" > "index.yaml";

    rm "${INPUTS_PACKAGES_DIR}/index.yaml";

}

function commit_changes() {
    
    git add "${INPUTS_PACKAGES_DIR}";

    git add "index.yaml";

    if git commit -m "Workflow updated Helm chart releases"; then

        git push;

    fi

}

function main() {

    mkdir -p ${INPUTS_PACKAGES_DIR};

    for CHART in ` find . -maxdepth 2 -type f -regex "./${INPUTS_BUILD_DIR}/.*\.tgz" `; do

        release_single_chart ${CHART};

    done

    update_index;

    commit_changes;

}

main;