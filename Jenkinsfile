env.ENV = 'dev'
env.IMAGE = 'codesenju/petclinic'
/* Docker */
env.DOCKERHUB_CREDENTIAL_ID = 'dockerhub_credentials'
/* Github  */
env.GITHUB_CRDENTIAL_ID = 'github_pvt_key'
env.GITHUB_REPO = 'spring-petclinic'
env.GITHUB_USERNAME = 'codesenju'
env.APP_NAME = 'spring-petclinic'
env.K8S_MANIFESTS_REPO = 'spring-petclinic-k8s'
/* AWS */
env.CLUSTER_NAME = 'uat'
env.AWS_REGION = 'us-east-1'
/* Argocd*/
env.ARGOCD_CLUSTER_NAME = 'in-cluster'
/* Sonarqube */
env.PETCLINIC_SONAR_TOKEN = 'petclinic_sonar_token'

pipeline {
    
    triggers {
    githubPush()
  }
 
    // agent {label 'k8s-agent'}
        agent {kubernetes {
        // inheritFrom 'k8s_agent' 
        yaml '''
kind: "Pod"
spec:
  nodeSelector:
    karpenter.sh/provisioner-name: "jenkins-agent"
  serviceAccount: jenkins-agent-sa
  containers:
  - name: "maven"
    image: "maven:3.9.4-eclipse-temurin-21-alpine"
    command:
    - cat
    tty: true
  - name: "jnlp"
    image: "codesenju/jenkins-inbound-agent:k8s"
    volumeMounts:
    - mountPath: "/var/run/docker.sock"
      name: "docker-socket"
    securityContext:
      runAsUser: 0
  volumes:
  - hostPath:
      path: "/var/run/docker.sock"
      type: Socket 
    name: "docker-socket"
    '''
    } }
    //environment {
        /* Set environment variables */

    //}
    
stages {
 
  stage('Checkout') {
      steps {
           script {
                      def gitUrl = "git@github.com:${GITHUB_USERNAME}/${GITHUB_REPO}.git"
                      def gitCredentialId = "${GITHUB_CRDENTIAL_ID}"
                  checkout([
                      $class: 'GitSCM',
                      branches: [[name: '*/main']],
                      doGenerateSubmoduleConfigurations: false,
                      extensions: [[$class: 'ScmName', name:"${GITHUB_REPO}"], [$class: 'RelativeTargetDirectory', relativeTargetDir: 'app-directory']],
                      submoduleCfg: [],
                      userRemoteConfigs: [[
                          credentialsId: gitCredentialId,
                          url: gitUrl
                      ]]
                  ])
         }
      }
  }//end-stage-checkout

        stage('Test') {
            parallel {
                stage('Code Quality') {
                    steps {
                        dir('app-directory'){
                            script {
                                container('maven'){
                                        withCredentials([string(credentialsId: "${env.PETCLINIC_SONAR_TOKEN}", variable: 'TOKEN')]) {
                                            sh '''
                                              mvn -DskipTests verify sonar:sonar \
                                              -Dsonar.projectKey=petclinic \
                                              -Dsonar.host.url=https://sonarqube.lmasu.co.za \
                                              -Dsonar.login=${TOKEN}
                                               '''
                                        }
                                }
                            }//end-app-directory
                        }
                    }
                } // end IaC
                stage('Unit Tests') {
                    steps {
                        dir('app-directory'){
                            script {
                               container('maven'){
                               sh '''
                                mvn test
                                '''
                               }
                            }
                        }//end-app-directory
                    }
                } // end Unit Test
                stage('Vulnerability Checks') {
                    steps {
                        dir('app-directory'){
                            script {
                              container('maven'){
                               sh '''
                                mvn -v
                                '''
                               }
                            }
                        }//end-app-directory
                    }
                } // end Unit Test
            }
        } // end Test

   
        stage('Build, Scan and Push') {
            steps {
                dir('app-directory'){
                    script {
                       sh '''
                            if ! command -v trivy &> /dev/null
                            then
                                echo "Trivy is not installed. Installing now."
                                curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin v0.22.0
                            else
                                echo "Trivy is already installed."
                            fi
                            trivy --version
                        '''
                        docker.withRegistry("https://registry.hub.docker.com", "${env.DOCKERHUB_CREDENTIAL_ID}") {
                            def customImage = docker.build("${env.IMAGE}:${env.BUILD_NUMBER}", "--network=host .")
                            /* Scan image for vulnerabilities */
                            sh "trivy image --exit-code 0 --severity HIGH --no-progress ${env.IMAGE}:${env.BUILD_NUMBER} || true"
                            sh "trivy image --exit-code 1 --severity CRITICAL --no-progress ${env.IMAGE}:${env.BUILD_NUMBER} || true"
                            /* Push the container to the custom Registry */
                            customImage.push()
                        }
                        // Create Artifacts which we can use if we want to continue our pipeline for other stages/pipelines
                        sh '''
                             printf '[{"app_name":"%s","image_name":"%s","image_tag":"%s"}]' "${APP_NAME}" "${IMAGE}" "${BUILD_NUMBER}" > build.json
                        '''
                   }//end-app-directory
                }
            }
        }

}//end-stages
}//end-pipeline
