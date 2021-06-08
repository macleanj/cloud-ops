#!/bin/bash

file=$1
s3_bucket=$2
partNumber=1
tempFileUploadId=tempMultiUploadId.txt
tempFileMultiPart=tempMultiPartUpload.json
tempFileMultiPartList=tempMultiPartUploadList.json

split -b 100mb $file
uploadId=$(aws s3api create-multipart-upload --bucket $s3_bucket --key $file | jq -r '.UploadId')
echo "uploadId = $uploadId"
echo "uploadId = $uploadId" > $tempFileUploadId

for first in {a..z}
do
  for second in {a..z}
  do
    for third in {a..z}
    do
      if [[ -f $first$second$third ]]; then
        echo "Uploading part $partNumber: $first$second$third"
        aws s3api upload-part --bucket $s3_bucket --key $file --part-number $partNumber --body $first$second$third --upload-id $uploadId
        ((partNumber=partNumber+1))
      fi
    done
  done
done

# Get overview of all uploads when missing uploadId
aws s3api list-multipart-uploads --bucket $s3_bucket > $tempFileMultiPartList

# recreate file
aws s3api list-parts --bucket $s3_bucket --key $file --upload-id $uploadId | jq '{Parts} | .Parts |= map({PartNumber, ETag})' > $tempFileMultiPart
aws s3api complete-multipart-upload --multipart-upload file://$tempFileMultiPart --bucket $s3_bucket --key $file --upload-id $uploadId

# Cleanup
rm $tempFileUploadId
rm $tempFileMultiPart
rm $tempFileMultiPartList