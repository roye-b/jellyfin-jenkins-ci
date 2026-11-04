
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
                                dotnet restore Jellyfin.sln
                                dotnet build Jellyfin.sln --no-restore
                            '''
                        }
                    }
                }

                stage('Web CI') {
                    steps {
                        dir('src/web') {
                            sh '''
                                echo "=== Jellyfin Web ==="
                                node --version
                                npm --version
                                npm ci
                                npm run build
                            '''
                        }
                    }
                }
            }
        }
    }
}
