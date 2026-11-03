
pipeline {
    agent {
        label 'jellyfin-agent'
    }

    stages {
        stage('Preflight') {
            steps {
                sh '''
                    echo "Checking Jenkins Agent"
                    hostname
                    java -version
                    git --version
                    docker version
                    docker buildx version
                '''
            }
        }
    }
}

