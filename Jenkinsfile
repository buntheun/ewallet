def label = "ewallet-${UUID.randomUUID().toString()}"

podTemplate(
    label: label,
    containers: [
        containerTemplate(
            name: 'jnlp',
            image: 'omisegoimages/jenkins-slave-ewallet:1.6-otp20',
            alwaysPullImage: true,
            args: '${computer.jnlpmac} ${computer.name}'
        ),
        containerTemplate(
            name: 'postgresql',
            image: 'postgres:9.6',
            ports: [
                portMapping(
                    name: 'postgresql',
                    containerPort: 5432,
                    hostPort: 5432
                )
            ]
        ),
    ],
    volumes: [
        hostPathVolume(
            mountPath: '/var/run/docker.sock',
            hostPath: '/var/run/docker.sock'
        ),
        hostPathVolume(
            mountPath: '/usr/bin/docker',
            hostPath: '/usr/bin/docker'
        ),
    ]
) {
    node(label) {
        Random random = new Random()
        def tmpDir = pwd(tmp: true)

        def project = 'gcr.io/omise-go'
        def appName = 'ewallet'
        def imageName = "${project}/${appName}"
        def releaseVersion = '0.1.0-beta'

        def nodeIP = getNodeIP()
        def gitCommit

        stage('Setup') {
            parallel(
                mix: { sh("mix do local.hex --force, local.rebar --force") },
                checkout: {
                    checkout scm
                    gitCommit = sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim()
                }
            )
        }

        stage('Test') {
            container('postgresql') {
                sh("pg_isready -t 60 -h localhost -p 5432")
            }

            withEnv([
                "MIX_ENV=test",
                "DATABASE_URL=postgresql://postgres@localhost:5432/ewallet_${gitCommit}_ewallet",
                "LOCAL_LEDGER_DATABASE_URL=postgresql://postgres@localhost:5432/ewallet_${gitCommit}_local_ledger"
            ]) {
                parallel(
                    compile_test: { sh("mix do deps.get, compile") },
                    format: { sh("mix do format --check-formatted") }
                )

                parallel(
                    credo: { sh("mix do credo") },
                    test: { sh("mix do ecto.create, ecto.migrate, test") }
                )
            }
        }

        stage('Build') {
            withEnv(["MIX_ENV=prod"]) {
                parallel(
                    compile_prod: { sh("mix do deps.get, compile") },
                    assets: {
                        dir("apps/admin_panel/assets") {
                            sh("yarn install")
                            sh("yarn build")
                        }
                    }
                )

                sh("mix release")
            }

            sh("mv _build/prod/rel/ewallet/releases/${releaseVersion}/ewallet.tar.gz .")
            sh("docker build --pull . -t ${imageName}:${gitCommit}")
        }

        stage('Push') {
            sh("gcloud auth configure-docker")
            sh("docker push ${imageName}:${gitCommit}")
        }
    }
}

String getNodeIP() {
    def rawNodeIP = sh(script: 'ip -4 -o addr show scope global', returnStdout: true).trim()
    def matched = (rawNodeIP =~ /inet (\d+\.\d+\.\d+\.\d+)/)
    return "" + matched[0].getAt(1)
}

String getPodID(String opts) {
    def pods = sh(script: "kubectl get pods ${opts} -o name", returnStdout: true).trim()
    def matched = (pods.split()[0] =~ /pods\/(.+)/)
    return "" + matched[0].getAt(1)
}
