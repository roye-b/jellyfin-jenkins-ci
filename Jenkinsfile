
pipeline {
    agent { label 'jellyfin-agent' }

    options {
        skipDefaultCheckout(true)
        timestamps()
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
                                userRemoteConfigs: [[url: source.data.repository]]
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
            }
        }

        stage('Parallel CI') {
            parallel {
                stage('Server CI') {
                    steps {
                        dir('src/server') {
                            sh '''
                                echo "=== Jellyfin Server ==="
                                dotnet --version

                                sed -i '/var client = _factory.CreateClient();/a\\            client.Timeout = System.TimeSpan.FromMinutes(10);' tests/Jellyfin.Server.Integration.Tests/OpenApiSpecTests.cs

                                dotnet restore Jellyfin.sln
                                dotnet build Jellyfin.sln --no-restore
                                dotnet test Jellyfin.sln --no-restore --no-build
                            '''
                        }
                    }
                }

                stage('Web CI') {
                    options {
                        timeout(time: 3000, unit: 'MINUTES')
                    }

                    steps {
                        dir('src/web') {
                            sh '''
                                echo "=== Jellyfin Web ==="
                                node --version
                                npm --version

                                npm ci --prefer-offline --no-audit --no-fund

                                echo "=== Configure Webpack Cache ==="
                                cp ../../ci/webpack.ci.js ./webpack.ci.js

                                echo "=== Build Jellyfin Web ==="
                                mkdir -p "$WORKSPACE/.webpack-cache"
                                NODE_ENV=production npx webpack --config webpack.ci.js

                                test -d dist
                            '''
                        }
                    }
                }
            }
        }

        stage('Prepare Docker Context') {
            steps {
                sh '''
                    echo "=== Prepare Docker Context ==="

                    rm -rf docker-context
                    mkdir -p docker-context/server docker-context/web

                    echo "=== Publish Jellyfin Server ==="
                    dotnet publish src/server/Jellyfin.Server/Jellyfin.Server.csproj \
                        -c Release \
                        --no-restore \
                        -o "$WORKSPACE/docker-context/server"

                    echo "=== Copy Jellyfin Web ==="
                    cp -a src/web/dist/. docker-context/web/

                    echo "=== Verify Artifacts ==="
                    test -f docker-context/server/jellyfin.dll
                    test -f docker-context/web/index.html
                '''
            }
        }

        stage('Docker Build') {
            steps {
                sh '''
                    echo "=== Build Docker Image ==="

                    docker build \
                        -f docker/Dockerfile \
                        -t jellyfin-ci:${BUILD_NUMBER} \
                        -t jellyfin-ci:latest \
                        .

                    echo "=== Docker Image ==="
                    docker image ls jellyfin-ci
                '''
            }
        }
    }
}
