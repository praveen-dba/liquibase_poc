// Same entry point as a local run: scripts/lb.sh.
// The job supplies the connection. Put these on the job as secret environment
// variables, or bind them from Jenkins credentials before this step:
//   LIQUIBASE_COMMAND_URL
//   LIQUIBASE_COMMAND_USERNAME
//   LIQUIBASE_COMMAND_PASSWORD
// MongoDB may omit the username when the server has no auth.
pipeline {
    agent any
    parameters {
        choice(name: 'TEAM', choices: ['service-team-a', 'service-team-b'])
        choice(name: 'ENGINE', choices: ['postgres', 'mysql', 'mongodb'])
        choice(name: 'COMMAND', choices: ['validate', 'status', 'update-sql', 'update', 'history', 'release-locks', 'rollback-count'])
        string(name: 'ROLLBACK_COUNT', defaultValue: '1', description: 'Used when COMMAND is rollback-count')
        string(name: 'SCHEMA', defaultValue: 'app', description: 'MySQL database or PostgreSQL schema. Ignored for MongoDB.')
    }
    stages {
        stage('migrate') {
            steps {
                sh '''
                    set -eu
                    if [ -z "${LIQUIBASE_COMMAND_URL:-}" ]; then
                      echo "Set LIQUIBASE_COMMAND_URL on this job. Username and password too, unless MongoDB has no auth." >&2
                      exit 1
                    fi
                    if [ "$COMMAND" = "rollback-count" ]; then
                      ./scripts/lb.sh rollback-count "$ROLLBACK_COUNT"
                    else
                      ./scripts/lb.sh "$COMMAND"
                    fi
                '''
            }
        }
    }
}
