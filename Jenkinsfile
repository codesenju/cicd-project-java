env.ENV = 'dev'
env.IMAGE = 'codesenju/petclinic'
/* Docker */
env.DOCKERHUB_CREDENTIAL_ID = 'dockerhub_credentials'
/* Github  */
env.GITHUB_CRDENTIAL_ID = 'github_pvt_key'
env.GITHUB_REPO = 'cicd-project-java'
env.GITHUB_USERNAME = 'codesenju'
env.APP_NAME = 'cicd-project-java'
env.K8S_MANIFESTS_REPO = 'cicd-project-k8s'
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
  tolerations:
    - key: "dedicated-jenkins-agent"
      operator: "Equal"
      effect: "NoExecute"
  containers:
  - name: "maven"
    image: "maven:3.9.4-eclipse-temurin-21-alpine"
    command:
    - cat
    tty: true
  - name: "jnlp"
    image: "codesenju/jenkins-inbound-agent:k8s"
    volumeMounts:
    - mountPath: "/var/run/"
      name: "docker-socket"
    securityContext:
      runAsUser: 0
  - name: "dind"
    image: "docker:dind"
    securityContext:
      privileged: true
    volumeMounts:
    - name: "docker-socket"
      mountPath: "/var/run"
  volumes:
  - name: "docker-socket"
    emptyDir: {}
    '''
    } }
    //environment {
        /* Set environment variables */

    //}
    
stages {
// // SKIP IF USING JENKINS ORGANISATION FOLDERS
//  stage('Checkout') {
//      steps {
//           script {
//                      def gitUrl = "git@github.com:${GITHUB_USERNAME}/${GITHUB_REPO}.git"
//                      def gitCredentialId = "${GITHUB_CRDENTIAL_ID}"
//                  checkout([
//                      $class: 'GitSCM',
//                      branches: [[name: '*/main']],
//                      doGenerateSubmoduleConfigurations: false,
//                      extensions: [[$class: 'ScmName', name:"${GITHUB_REPO}"], [$class: 'RelativeTargetDirectory', relativeTargetDir: 'app-directory']],
//                      submoduleCfg: [],
//                      userRemoteConfigs: [[
//                          credentialsId: gitCredentialId,
//                          url: gitUrl
//                      ]]
//                  ])
//         }
//      }
//  }//end-stage-checkout

        stage('Test') {
            parallel {
                stage('Code Quality') { // start-CodeQuality
                    steps {
                            script { //start-scrip
                                container('maven'){
                                        withCredentials([string(credentialsId: "${env.PETCLINIC_SONAR_TOKEN}", variable: 'TOKEN')]) {
                                            sh '''
                                              mvn -DskipTests verify sonar:sonar \
                                              -Dsonar.projectKey=petclinic \
                                              -Dsonar.host.url=https://sonarqube.lmasu.co.za \
                                              -Dsonar.login=${TOKEN} \
                                              -Dsonar.qualitygate.wait=true
                                               '''
                                        }
                                }
                            } //end-scrip
                    }
                } // end-CodeQuality
                stage('Unit Tests') {
                    steps {
                            script {
                               container('maven'){
                               sh '''
                                mvn test
                                '''
                               }
                            }
                    }
                } // end Unit Test
                stage('Owasp Dependency Check') {
                    steps {
                            script {
                              container('maven'){
                               sh '''
                                mvn org.owasp:dependency-check-maven:check
                                '''
                               }
                            }
                    }
                } // end Unit Test
            }
        } // end Test

   
        stage('Build, Scan and Push') {
            steps {
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
                   }//end-script
            }
        }
    stage('Deploy - DEV') {
    steps { 
            sh 'echo Install kubectl cli...'
            sh 'curl -o /usr/bin/kubectl https://s3.us-west-2.amazonaws.com/amazon-eks/1.27.4/2023-08-16/bin/linux/amd64/kubectl && chmod +x /usr/bin/kubectl'
            sh 'kubectl version --short --client'
            sh "echo 'Install Argocd cli & Authenticate with Argocd Server...'"
            sh 'curl -sLo /usr/bin/argocd https://github.com/argoproj/argo-cd/releases/download/v2.7.2/argocd-linux-amd64 && chmod +x /usr/bin/argocd'
            sh 'argocd version --client'
            sh 'echo Install kustomize cli...'
            sh 'curl -sLo /tmp/kustomize.tar.gz  https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv5.0.3/kustomize_v5.0.3_linux_amd64.tar.gz'
            sh 'tar xzvf /tmp/kustomize.tar.gz -C /usr/bin/ && chmod +x /usr/bin/kustomize && rm -rf /tmp/kustomize.tar.gz'
            sh 'kustomize version'
            sh 'aws eks update-kubeconfig --region ${AWS_REGION} --name ${CLUSTER_NAME}'
            // sh "kubectl cluster-info"
                script {
                    def gitUrl = "git@github.com:${GITHUB_USERNAME}/${K8S_MANIFESTS_REPO}.git"
                    def gitCredentialId = "${GITHUB_CRDENTIAL_ID}"
                // Updating k8s repo with non gitSCM method to aviod non stop build triggers
                // Alternative to second SCM we will clone manually
                withCredentials([sshUserPrivateKey(credentialsId: gitCredentialId, keyFileVariable: 'SSH_KEY')]) {
                    sh '''eval `ssh-agent -s`
                          ssh-add $SSH_KEY
                          ssh -o StrictHostKeyChecking=no git@github.com || true
                          TEMPDIR=$(mktemp -d)
                          cd $TEMPDIR
                          git clone git@github.com:${GITHUB_USERNAME}/${K8S_MANIFESTS_REPO}.git
                          cd $K8S_MANIFESTS_REPO/$APP_NAME/k8s/$ENV
                          ls -la
                          git status
                          git remote -v
                          cat kustomization.yaml | head -n 13
                          kustomize edit set image KUSTOMIZE=${IMAGE}:${BUILD_NUMBER}
                          cat kustomization.yaml | head -n 13
                          git config --global user.email "devops@jenkins-pipeline.com"
                          git config --global user.name "jenkins-k8s-agent"
                          git add kustomization.yaml
                          git commit -m "Updated ${APP_NAME} image to ${IMAGE}:${BUILD_NUMBER}" || true
                          git status
                          git push origin HEAD:main
                    '''
                }//end-withCredentials
                //}//end-dir
             
           // Argocd Deployment - DEV
            sh 'echo "Authenticate with Argocd Server..."'
            def ARGOCD_CREDS = sh(script: 'aws secretsmanager get-secret-value --secret-id iac-my-argocd-secret --query SecretString --output text', returnStdout: true).trim()
             wrap([$class: 'MaskPasswordsBuildWrapper', varPasswordPairs: [[password: ARGOCD_CREDS]]]) {  
                  withEnv(["SECRET=${ARGOCD_CREDS}"]){
                      
                       def ARGOCD_USERNAME = sh(script: 'echo $SECRET | jq -r .username',returnStdout: true).trim()
                       def ARGOCD_SERVER = sh(script: 'echo $SECRET | jq -r .server', returnStdout: true).trim()
                       def ARGOCD_PASSWORD = sh(script: 'echo $SECRET | jq -r .password',returnStdout: true).trim()
                       
                    // Masks argocd username, password and server
                    wrap([$class: 'MaskPasswordsBuildWrapper', varPasswordPairs: [[password: ARGOCD_PASSWORD],[password: ARGOCD_USERNAME], [password: ARGOCD_SERVER]]]) {
                        withEnv(["USERNAME=${ARGOCD_USERNAME}", "PASSWORD=${ARGOCD_PASSWORD}","SERVER=${ARGOCD_SERVER}"]){
                           sh 'argocd login $SERVER --username $USERNAME --password $PASSWORD'
                               sh 'ls -la'
                               sh 'cat argocd.yaml'
                               // Assuming repo already added to argocd server
                            // Create argocd app if it doesn't exist already
                              def status = sh(script: 'argocd app get $APP_NAME', returnStatus: true)
                              if (status != 0) {
                                 sh 'echo "Argocd app doesnt exist, creating app..."'
                                 sh 'cat argocd.yaml | envsubst'
                                 sh '''
                                    pwd
                                    ls -l
                                    '''
                                 sh 'cat argocd.yaml | envsubst | argocd app create --upsert -f -'
                               } else {
                                  echo 'Argocd app already exists.'
                               }
                               sh '''
                                 argocd app get $APP_NAME --refresh
                                 argocd app wait $APP_NAME
                                '''
                        }//end-withEnv
                    } //end-wrap
                  }//end-withEnv
             }//end-wrap
       }//end-script
    }//end-steps
}//end-stage-deploy-dev

}//end-stages
}//end-pipeline