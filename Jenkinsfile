pipeline {
    agent { label 'slave-1' }

    tools {
        jdk 'jdk21'
        maven 'maven3'
    }

    options {
        disableConcurrentBuilds()
        buildDiscarder(logRotator(
            numToKeepStr: '10',
            artifactNumToKeepStr: '5'
        ))
        timestamps()
        ansiColor('xterm')
        timeout(time: 180, unit: 'MINUTES')
    }

    parameters {
        string(
            name: 'GIT_BRANCH',
            defaultValue: 'devops',
            description: 'Git branch to build'
        )
        booleanParam(
            name: 'DEPLOY',
            defaultValue: true,
            description: 'Deploy after successful build'
        )
    }

    environment {
        AWS_REGION      = 'ap-south-1'
        AWS_ACCOUNT_ID  = '274955213592'
        ECR_REPOSITORY  = 'spring-petclinic'
        IMAGE_TAG       = "${BUILD_NUMBER}"
        IMAGE_URI       = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPOSITORY}:${IMAGE_TAG}"
        GITOPS_REPO     = 'https://github.com/Rajesh-210/spring-petclinic-k8s.git'
    }

    stages {

        stage('Checkout Source') {
            steps {
                echo "Checking out ${params.GIT_BRANCH}"
                git(
                    branch: params.GIT_BRANCH,
                    credentialsId: 'github',
                    url: 'https://github.com/Rajesh-210/spring-petclinic.git'
                )
            }
        }

        stage('Verify Tools') {
            steps {
                sh '''
                    java -version
                    mvn -version
                    docker --version
                    trivy --version
                '''
            }
        }

        stage('Compile') {
            steps {
                sh '''
                    mvn clean compile
                '''
            }
        }
        stage('Clean Docker Environment') {
            steps {
                sh '''
                   echo "Cleaning previous Docker Compose resources..."

                   docker compose down -v --remove-orphans || true

                   docker container prune -f || true
                   docker network prune -f || true

                   docker ps -a
               '''
            }
        }

        stage('Unit Test') {
            steps {
                sh '''
                    mvn test
                '''
            }
            post {
                always {
                    junit '**/target/surefire-reports/*.xml'
                }
            }
        }

        stage('Package') {
            steps {
                sh '''
                    mvn package -DskipTests
                '''
            }
        }

        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('sonarqube') {
                    sh """
                        mvn sonar:sonar \
                            -Dsonar.projectKey=spring-petclinic \
                            -Dsonar.projectName=spring-petclinic \
                            -Dsonar.projectVersion=${BUILD_NUMBER}
                    """
                }
            }
        }

        stage('Quality Gate') {
            steps {
                timeout(time: 10, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        stage('OWASP Dependency Check') {
            options {
                timeout(time: 90, unit: 'MINUTES')
            }
            steps {
                script {
                    def DC_HOME = tool 'DP-Check'
                    withCredentials([
                        string(credentialsId: 'nvd-api-key', variable: 'NVD_API_KEY')
                    ]) {
                        sh '''
                            mkdir -p dependency-check-report
                        '''
                        sh """
                            ${DC_HOME}/bin/dependency-check.sh \
                                --project spring-petclinic \
                                --scan . \
                                --format XML \
                                --format HTML \
                                --out dependency-check-report \
                                --nvdApiKey ${NVD_API_KEY}
                        """
                    }
                }
            }
        }

        stage('Publish Dependency Check Report') {
            steps {
                publishHTML(target: [
                    allowMissing: true,
                    alwaysLinkToLastBuild: true,
                    keepAll: true,
                    reportDir: 'dependency-check-report',
                    reportFiles: 'dependency-check-report.html',
                    reportName: 'OWASP Dependency Check Report'
                ])
            }
        }

        stage('Trivy Filesystem Scan') {
            steps {
                sh '''
                    trivy fs \
                        --format table \
                        --output trivy-fs-report.txt \
                        .
                '''
            }
        }

        stage('Docker Build') {
            steps {
                sh """
                    docker build \
                        -t ${IMAGE_URI} .
                """
            }
        }

        stage('Trivy Image Scan') {
            steps {
                sh """
                    trivy image \
                        --severity HIGH,CRITICAL \
                        --format table \
                        --output trivy-image-report.txt \
                        ${IMAGE_URI}
                """
            }
        }

    }

    post {
        always {
            archiveArtifacts artifacts: '''
                dependency-check-report/**
                trivy-fs-report.txt
                trivy-image-report.txt
            '''.trim(), allowEmptyArchive: true,
                fingerprint: true
        }
    }

}
