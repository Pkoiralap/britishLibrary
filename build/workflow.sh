echo "Fetching the data repository to build a data xar"
git clone https://github.com/srophe/britishLibrary-data

cd britishLibrary-data
rm -rf build
mkdir build
echo "Running data build ..."
ant
echo "Ran data build successfully"

cd ..
# remove any old auto deploy
rm -rf autodeploy
# create an autodeploy folder
mkdir autodeploy

echo "Running app build ..."
ant
echo "Ran app build successfully"


# move the xar from build to autodeploy
mv build/*.xar autodeploy/
mv britishLibrary-data/build/*.xar autodeploy/

rm -rf britishLibrary-data

# use sed to replace the template git-sync with secrets and other
TEMPLATE_FILE="./build/git-sync_template.xql"
DESTINATION_FILE="./conf/git-sync.xql"

echo "Copying secret key over"
# SECRET_KEY, $ADMIN_PASSWORD
sed \
    -e "s/\${SECRET_KEY}/$SECRET_KEY/" \
    $TEMPLATE_FILE > $DESTINATION_FILE
echo "Copied secret key over successfully"

# GET the version of the project from the expath-pkg.xml
VERSION=$(cat expath-pkg.xml | grep package | grep version=  | awk -F'version="' '{ print $2 }' | awk -F'"' '{ print $1 }')
# GET the package name of the project from the expath-pkg.xml file
PACKAGE_NAME=$(cat expath-pkg.xml | grep package | grep version=  | awk -F'abbrev="' '{ print $2 }' | awk -F'"' '{ print tolower($1) }')

echo "Deploying app $PACKAGE_NAME:$VERSION"


echo "Building docker file"
docker build -t "$PACKAGE_NAME:$VERSION" --build-arg ADMIN_PASSWORD="$ADMIN_PASSWORD" --no-cache .
echo docker build -t "$PACKAGE_NAME:$VERSION" --build-arg ADMIN_PASSWORD="$ADMIN_PASSWORD" --no-cache .
echo "Built successfully"

DOCKER_URL=$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$ECR_REPOSITORY:latest

echo "Loging in to AWS"
# Get the aws docker login creds. Note: only works if the github repo is allowed access from OIDC
aws ecr get-login-password --region $AWS_REGION | \
docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com 
echo "Logged in successfully"

docker tag $PACKAGE_NAME:$VERSION $DOCKER_URL
echo "Pushing to $DOCKER_URL"
docker push $DOCKER_URL

echo "Pushed successfully, wait for a few minutes to see the changes reflected"
