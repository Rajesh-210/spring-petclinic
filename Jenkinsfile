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
        timeout(time: 60, unit: 'MINUTES')
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

        AWS_REGION = 'ap-south-1'
        AWS_ACCOUNT_ID = '274955213592'
        ECR_REPOSITORY = 'spring-petclinic'

        IMAGE_TAG = "${BUILD_NUMBER}"

        IMAGE_URI = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPOSITORY}:${IMAGE_TAG}"

        GITOPS_REPO = 'https://github.com/Rajesh-210/spring-petclinic-k8s.git'

    }

    stages {

        stage('Checkout Source') {

            steps {

                echo "Checking out ${params.GIT_BRANCH}"

                git(
                    branch: params.GIT_BRANCH,
                    credentialsId: 'YOUR_GITHUB_CREDENTIAL_ID',
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
                    -Dsonar.projectName=spring-petclinic
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
