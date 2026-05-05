version=0.2.2
source_file=modules/secda_tools/${version}/source.json
url=$(jq -r '.url' ${source_file})
integrity=$(jq -r '.integrity' ${source_file})
echo "Integrity value from ${source_file}: ${integrity}"

pushd ./releases
rm -f secda_tools-${version}.tar.gz
rm -f ${version}.tar.gz
wget ${url}
mv -f ${version}.tar.gz secda_tools-${version}.tar.gz
new_integrity="sha256-$(openssl dgst -sha256 -binary secda_tools-${version}.tar.gz | openssl base64 -A)"
popd

if [ "${integrity}" != "${new_integrity}" ]; then
  echo "Integrity check failed for secda_tools-${version}.tar.gz"
  

  echo "Expected integrity: ${integrity}"
  echo "Actual integrity: ${new_integrity}"
  echo "Updating integrity value in ${source_file}..."
  echo "New integrity value: ${new_integrity}"
  jq --arg new_integrity "${new_integrity}" '.integrity = $new_integrity' ${source_file} > tmp.json && mv tmp.json ${source_file}
  echo "Integrity value updated in ${source_file}"

else
  echo "Integrity check passed for secda_tools-${version}.tar.gz"
fi