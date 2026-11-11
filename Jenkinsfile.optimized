
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
                    echo "WORKSPACE: ${pwd()}"

                    sh '''
                        echo "=== Checking source-lock.json ==="
                        ls -lh ci/source-lock.json
                        python3 -m json.tool ci/source-lock.json
                    '''

                    def lock = readJSON(
                        file: 'ci/source-lock.json',
                        returnPojo: true
                    )

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

