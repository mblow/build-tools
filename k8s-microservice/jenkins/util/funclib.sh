# General utilities shell functions for k8s-microservice scripts

function product_in_rhcc {
    local PRODUCT=$1

    if [ "${PRODUCT}" = "couchbase-service-broker" -o "${PRODUCT}" = "couchbase-observability-stack" ]; then
        return 1
    fi

    return 0
}

function tag_release {
    if [ ${#} -ne 3 ]
    then
        error "expected [product] [version] [build_number], got ${@}"
    fi
    local PRODUCT=$1
    local VERSION=$2
    local BLD_NUM=$3

    curl --fail -LO http://latestbuilds.service.couchbase.com/builds/latestbuilds/${PRODUCT}/${VERSION}/${BLD_NUM}/${PRODUCT}-${VERSION}-${BLD_NUM}-manifest.xml

    REVISION=$(xmllint --xpath "string(//project[@name=\"${PRODUCT}\"]/@revision)" ${PRODUCT}-${VERSION}-${BLD_NUM}-manifest.xml)
    DEFAULT_REMOTE=$(xmllint --xpath "string(//default/@remote)" ${PRODUCT}-${VERSION}-${BLD_NUM}-manifest.xml)
    PROJECT_REMOTE=$(xmllint --xpath "string(//project[@name=\"${PRODUCT}\"]/@remote)" ${PRODUCT}-${VERSION}-${BLD_NUM}-manifest.xml)

    if [ "${PROJECT_REMOTE}" != "" ]
    then
        GERRIT_HOST=$(xmllint --xpath "string(//remote[@name=\"${PROJECT_REMOTE}\"]/@review)" ${PRODUCT}-${VERSION}-${BLD_NUM}-manifest.xml)
    else
        GERRIT_HOST=$(xmllint --xpath "string(//remote[@name=\"${DEFAULT_REMOTE}\"]/@review)" ${PRODUCT}-${VERSION}-${BLD_NUM}-manifest.xml)
    fi

    git clone "ssh://${GERRIT_HOST}:29418/${PRODUCT}.git"

    pushd "${PRODUCT}"
    if [ "${REVISION}" = "" ]
    then
        error "Got empty revision from manifest, couldn't tag release"
    elif ! test "$(git cat-file -t ${REVISION})" = "commit"
    then
        error "Expected to find a commit, found a $(git cat-file -t ${REVISION}) instead"
    else
        if git tag | grep "${VERSION}" &>/dev/null
        then
            error "Tag ${VERSION} already exists, please investigate ($(git rev-parse -n1 ${VERSION}))"
        else
            git tag -a "${VERSION}" "${REVISION}" -m "Version ${VERSION}"
            git push "ssh://${GERRIT_HOST}:29418/${PRODUCT}.git" ${VERSION}
        fi
    fi
    popd
}