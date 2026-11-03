
pipeline {
    agent {
        label 'jellyfin-agent'
    }

    options {
        skipDefaultCheckout(true)
        timestamps()
    }

    stages {
        stage('Checkout and Preflight') {
            steps {
                checkout scm

                script {
                    def lock = readJSON file: 'ci/source-lock.json'

                    def sources = [
                        [name: 'server', path: 'src/server',
                         data: lock.server],
                        [name: 'web', path: 'src/web',
                         data: lock.web]
                    ]

                    for (source in sources) {
                        dir(source.path) {
                            checkout([
                                $class: 'GitSCM',
                                branches: [[
                                    name: source.data.commit
                                ]],
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
                    echo "=== Agent ==="
                    hostname
                    uname -m
                    java -version
                    git --version

                    echo "=== Docker ==="
                    docker version
                    docker buildx version
                '''
            }
        }
    }
}
