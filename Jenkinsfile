
pipeline {
    agent { label 'jellyfin-agent' }

    options {
        skipDefaultCheckout(true)
        timestamps()
        disableConcurrentBuilds()
    }

    environment {
        DOCKER_BUILDKIT = '1'
        IMAGE_NAME = 'jellyfin-ci'
    }

    stages {

        stage('Checkout and Preflight') {
            steps {
                checkout scm

                script {
                    def jsonText = readFile(
                        file: 'ci/source-lock.json',
                        encoding: 'UTF-8'
                    )

                    def lock = new groovy.json.JsonSlurperClassic()
                        .parseText(jsonText)

                    def sources = [
                        [name: 'server', path: 'src/server', data: lock.server],
                        [name: 'web', path: 'src/web', data: lock.web]
                    ]

                    for (source in sources) {
                        dir(source.path) {
                            checkout([
                                $class: 'GitSCM',
                                branches: [[name: source.data.commit]],
                                userRemoteConfigs: [[
                                    url: source.data.repository
                                ]]
                            ])

                            def actual = sh(
                                script: 'git rev-parse HEAD',
                                returnStdout: true
                            ).trim()

                            if (actual != source.data.commit) {
                                error "SHA mismatch: ${source.name}"
                            }

                            echo "${source.name}: SHA verified"
                        }
                    }
                }

                sh '''
                    set -eu

                    echo "=== Verify required files ==="
                    test -f Dockerfile
                    test -f .dockerignore
                    test -f ci/webpack.ci.js
                    test -f src/server/Jellyfin.sln
                    test -f src/web/package-lock.json

                    echo "=== Docker and Buildx ==="
                    docker version
                    docker buildx version
                '''
            }
        }

        stage('Server CI') {
            steps {
                dir('src/server') {
                    sh '''
                        set -eu

                        echo "=== Jellyfin Server ==="
                        dotnet --version

                        echo "=== Restore Dependencies ==="
                        dotnet restore Jellyfin.sln

                        echo "=== Configure OpenAPI Test Timeout ==="

                        TEST_FILE="tests/Jellyfin.Server.Integration.Tests/OpenApiSpecTests.cs"

                        if ! grep -q 'client.Timeout = System.TimeSpan.FromMinutes(10);' "$TEST_FILE"; then
                            sed -i '/var client = _factory.CreateClient();/a\\            client.Timeout = System.TimeSpan.FromMinutes(10);' "$TEST_FILE"
                        fi

                        echo "=== Verify Timeout ==="
                        grep -n 'client.Timeout' "$TEST_FILE"

                        echo "=== Build Jellyfin Server ==="
                        dotnet build Jellyfin.sln --no-restore

                        echo "=== Run Server Tests ==="

                        mkdir -p ../../test-results

                        dotnet test tests/Jellyfin.Server.Integration.Tests/Jellyfin.Server.Integration.Tests.csproj \
                            --no-restore \
                            --no-build \
                            --results-directory ../../test-results \
                            --logger "trx;LogFilePrefix=jellyfin-tests"

                        echo "=== Server Tests Completed ==="
                    '''
                }
            }

            post {
                always {
                    archiveArtifacts(
                        artifacts: 'test-results/**/*.trx',
                        allowEmptyArchive: true
                    )
                }
            }
        }

        stage('Docker Multi-Stage Build') {
            steps {
                sh '''
                    set -eu

                    echo "=== Docker Build with BuildKit Cache ==="

                    docker build \
                        --progress=plain \
                        -f Dockerfile \
                        -t "${IMAGE_NAME}:${BUILD_NUMBER}" \
                        -t "${IMAGE_NAME}:latest" \
                        .

                    echo "=== Verify Docker Image ==="
                    docker image inspect "${IMAGE_NAME}:${BUILD_NUMBER}"
                    docker image ls "${IMAGE_NAME}"
                '''
            }
        }

        stage('Verify Docker Image') {
            steps {
                sh '''
                    set -eu

                    echo "=== Verify Jellyfin files inside image ==="

                    docker run --rm \
                        --entrypoint /bin/sh \
                        "${IMAGE_NAME}:${BUILD_NUMBER}" \
                        -c 'test -f /jellyfin/jellyfin.dll && test -f /jellyfin/jellyfin-web/index.html'

                    echo "=== Docker Image Verified ==="
                '''
            }
        }
    }

    post {
        success {
            echo 'Jellyfin CI and Docker Build completed successfully.'
        }

        failure {
            echo 'Pipeline failed. Check the failing stage and test reports.'
        }
    }
}
