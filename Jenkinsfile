
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
        OPTIMIZED_DOCKERFILE = 'Dockerfile.optimized'
    }

    stages {

        stage('Checkout and Preflight') {
            steps {
                checkout scm

                script {
		    def lock = readJSON text: readFile('ci/source-lock.json').trim(), returnPojo: true

					def utils = load 'ci/pipelineUtils.groovy'

					utils.requireRepository(lock.server.repository)
					utils.requireRepository(lock.web.repository)

					utils.requireRevision(lock.server.commit)
					utils.requireRevision(lock.web.commit)

					echo 'Groovy Helpers: source lock validation passed'

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

                    test -f Dockerfile.optimized
                    test -f Dockerfile.optimized.dockerignore
                    test -f ci/webpack.ci.js
                    test -f src/server/Jellyfin.sln
                    test -f src/web/package-lock.json

                    docker version
                    docker buildx version

                    mkdir -p docker-context/server
                    mkdir -p docker-context/web
                    rm -rf test-results
                    mkdir -p test-results

                    echo "=== Build SDK Images ==="

                    docker build \
                        --target server-build \
                        -f Dockerfile.optimized \
                        -t jellyfin-server-sdk:ci .

                    docker build \
                        --target web-build \
                        -f Dockerfile.optimized \
                        -t jellyfin-web-sdk:ci .
                '''
            }
        }

        stage('Parallel CI') {
            parallel {
            stage('Server CI - Docker') {
                steps {
                    sh '''
                        set -eu
    
                        echo "=== Server CI inside Docker ==="
    
                        docker volume create jellyfin-nuget-cache >/dev/null
    
                        docker run --rm \
                            -v "$WORKSPACE:/workspace" \
                            -v jellyfin-nuget-cache:/root/.nuget/packages \
                            -w /workspace/src/server \
                            jellyfin-server-sdk:ci \
                            /bin/sh -ec '
                                dotnet --version
    
                                dotnet restore Jellyfin.sln --disable-parallel --source https://api.nuget.org/v3/index.json
    
                                TEST_FILE="tests/Jellyfin.Server.Integration.Tests/OpenApiSpecTests.cs"
    
                                if ! grep -q "client.Timeout = System.TimeSpan.FromMinutes(10);" "$TEST_FILE"; then
                                    sed -i "/var client = _factory.CreateClient();/a\\            client.Timeout = System.TimeSpan.FromMinutes(10);" "$TEST_FILE"
                                fi
    
                                dotnet build Jellyfin.sln \
                                    -c Release \
                                    --no-restore
    
                                mkdir -p /workspace/test-results

                                echo "=== Run all 16 server test projects with TRX and coverage ==="
                                count=0
                                for project in tests/*/*.csproj; do
                                    name=$(basename "$project" .csproj)
                                    echo "=== Testing $name ==="
                                    dotnet test "$project" \
                                        -c Release \
                                        --no-restore \
                                        --no-build \
                                        --results-directory "/workspace/test-results/$name" \
                                        --logger "trx;LogFileName=$name.trx" \
                                        --collect:"XPlat Code Coverage"
                                    test -s "/workspace/test-results/$name/$name.trx" || {
                                        echo "ERROR: Missing TRX report for $name"
                                        exit 1
                                    }
                                    count=$((count + 1))
                                done
                                test "$count" -eq 16 || {
                                    echo "ERROR: Expected 16 test projects; found $count"
                                    exit 1
                                }
                                echo "All $count server test projects passed"
    
                                dotnet publish \
                                    Jellyfin.Server/Jellyfin.Server.csproj \
                                    -c Release \
                                    --no-restore \
                                    -o /workspace/docker-context/server
    
                                test -f /workspace/docker-context/server/jellyfin.dll
                            '
    
                    '''
                }
    
                post {
                    always {
                        script {
                            try {
                                if (sh(
                                    script: 'find test-results -mindepth 2 -maxdepth 2 -name "*.trx" -print -quit | grep -q .',
                                    returnStatus: true
                                ) == 0) {
                                    sh 'python3 ci/trx-to-junit.py test-results'

                                    junit(
                                        testResults: 'test-results/junit/*.xml',
                                        allowEmptyResults: false
                                    )

                                    recordCoverage(
                                        ignoreParsingErrors: true,
                                        tools: [[
                                            parser: 'COBERTURA',
                                            pattern: 'test-results/*/*/coverage.cobertura.xml'
                                        ]]
                                    )
                                } else {
                                    echo 'No TRX reports found; skipping JUnit and Coverage publishing.'
                                }
                            } finally {
                                archiveArtifacts(
                                    artifacts: 'test-results/**/*',
                                    allowEmptyArchive: true
                                )
                            }
                        }
                    }
                }
            }
    
            stage('Web CI - Docker') {
                steps {
                    sh '''
                        set -eu
    
                        echo "=== Web CI inside Docker ==="
    
                        docker volume create jellyfin-npm-cache >/dev/null
                        docker volume create jellyfin-webpack-cache >/dev/null
    
                        cp ci/webpack.ci.js src/web/webpack.ci.js
    
                        docker run --rm \
                            -v "$WORKSPACE:/workspace" \
                            -v jellyfin-npm-cache:/root/.npm \
                            -v jellyfin-webpack-cache:/src/web/.webpack-cache \
                            -w /workspace/src/web \
                            -e WEBPACK_CACHE_DIR=/src/web/.webpack-cache \
                            jellyfin-web-sdk:ci \
                            /bin/sh -ec '
                                node --version
                                npm --version
    
                                npm ci --include=dev \
                                    --prefer-offline \
                                    --no-audit \
                                    --no-fund
    
                                npm run build:check
    
                                npm test -- --run --testTimeout=30000
    
                                ./node_modules/.bin/webpack \
                                    --config webpack.ci.js
    
                                test -f dist/index.html
    
                                cp -a dist/. /workspace/docker-context/web/
                            '
                    '''
                }
            }
            }
        }

        stage('Docker Runtime Build') {
            steps {
                sh '''
                    set -eu

                    echo "=== Verify Build Artifacts ==="

                    test -f docker-context/server/jellyfin.dll
                    test -f docker-context/web/index.html

                    echo "=== Build Runtime Image ==="

                    docker build \
                        --progress=plain \
                        -f Dockerfile.optimized \
                        -t "${IMAGE_NAME}:${BUILD_NUMBER}" \
                        -t "${IMAGE_NAME}:optimized" \
                        .

                    docker image inspect "${IMAGE_NAME}:${BUILD_NUMBER}"
                '''
            }
        }

        stage('Verify Docker Image') {
            steps {
                sh '''
                    set -eu

                    docker run --rm \
                        --entrypoint /bin/sh \
                        "${IMAGE_NAME}:${BUILD_NUMBER}" \
                        -c 'test -f /jellyfin/jellyfin.dll && test -f /jellyfin/jellyfin-web/index.html'

                    echo "=== Running Jellyfin Smoke Test ==="

                    bash ci/smoke/smoke-test.sh "${IMAGE_NAME}:${BUILD_NUMBER}"

                    echo "=== Docker Image and Smoke Test Verified ==="
                '''
            }
        }
    }

    post {
        success {
            echo 'Optimized Jellyfin CI completed successfully.'
        }

        failure {
            echo 'Optimized Pipeline failed. Check logs and reports.'
        }

        always {
            archiveArtifacts(
                artifacts: 'smoke-results/**/*',
                allowEmptyArchive: true
            )
            sh '''
                if [ -d docker-context ]; then
                    docker run --rm \
                        -v "$WORKSPACE:/workspace" \
                        --entrypoint /bin/sh \
                        jellyfin-server-sdk:ci \
                        -c "chown -R 110:110 /workspace/docker-context /workspace/test-results" \
                        2>/dev/null || true
                fi
            '''
        }
    }
}
