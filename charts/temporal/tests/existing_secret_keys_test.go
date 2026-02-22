package test

import (
	"path/filepath"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	appsv1 "k8s.io/api/apps/v1"
	batchv1 "k8s.io/api/batch/v1"
	corev1 "k8s.io/api/core/v1"

	"github.com/gruntwork-io/terratest/modules/helm"
	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/gruntwork-io/terratest/modules/random"
)

// --- helpers ---

func findEnv(envVars []corev1.EnvVar, name string) *corev1.EnvVar {
	for i := range envVars {
		if envVars[i].Name == name {
			return &envVars[i]
		}
	}
	return nil
}

func requirePlainEnv(t *testing.T, envVars []corev1.EnvVar, name, want string) {
	t.Helper()
	ev := findEnv(envVars, name)
	require.NotNilf(t, ev, "env var %s not found", name)
	assert.Nilf(t, ev.ValueFrom, "env var %s: expected plain value, got valueFrom", name)
	assert.Equalf(t, want, ev.Value, "env var %s", name)
}

func requireSecretRef(t *testing.T, envVars []corev1.EnvVar, envName, secretName, secretKey string) {
	t.Helper()
	ev := findEnv(envVars, envName)
	require.NotNilf(t, ev, "env var %s not found", envName)
	require.NotNilf(t, ev.ValueFrom, "env var %s: expected valueFrom", envName)
	require.NotNilf(t, ev.ValueFrom.SecretKeyRef, "env var %s: expected secretKeyRef", envName)
	assert.Equal(t, secretName, ev.ValueFrom.SecretKeyRef.Name)
	assert.Equal(t, secretKey, ev.ValueFrom.SecretKeyRef.Key)
}

func findInitContainer(containers []corev1.Container, name string) *corev1.Container {
	for i := range containers {
		if containers[i].Name == name {
			return &containers[i]
		}
	}
	return nil
}

func sqlBaseValues() map[string]string {
	return map[string]string{
		"cassandra.enabled":                                 "false",
		"mysql.enabled":                                     "true",
		"elasticsearch.enabled":                             "false",
		"server.config.persistence.default.driver":          "sql",
		"server.config.persistence.default.sql.host":        "myhost",
		"server.config.persistence.default.sql.port":        "3306",
		"server.config.persistence.default.sql.user":        "myuser",
		"server.config.persistence.default.sql.password":    "mypass",
		"server.config.persistence.default.sql.database":    "mydb",
		"server.config.persistence.visibility.driver":       "sql",
		"server.config.persistence.visibility.sql.host":     "vis-host",
		"server.config.persistence.visibility.sql.port":     "5432",
		"server.config.persistence.visibility.sql.user":     "visuser",
		"server.config.persistence.visibility.sql.password": "vispass",
		"server.config.persistence.visibility.sql.database": "visdb",
	}
}

func setValues(base map[string]string, extra map[string]string) map[string]string {
	merged := make(map[string]string, len(base)+len(extra))
	for k, v := range base {
		merged[k] = v
	}
	for k, v := range extra {
		merged[k] = v
	}
	return merged
}

// --- Deployment: SQL backward compat ---

func TestDeploymentSqlNoExistingSecretKeys(t *testing.T) {
	chartPath, err := filepath.Abs("../")
	require.NoError(t, err)
	ns := "temporal-" + strings.ToLower(random.UniqueId())

	opts := &helm.Options{
		SetValues:         sqlBaseValues(),
		KubectlOptions:    k8s.NewKubectlOptions("", "", ns),
		BuildDependencies: false,
	}

	out := helm.RenderTemplate(t, opts, chartPath, "temporal", []string{"templates/server-deployment.yaml"})
	var dep appsv1.Deployment
	helm.UnmarshalK8SYaml(t, out, &dep)

	env := dep.Spec.Template.Spec.Containers[0].Env
	requirePlainEnv(t, env, "TEMPORAL_STORE_HOST", "myhost")
	requirePlainEnv(t, env, "TEMPORAL_STORE_PORT", "3306")
	requirePlainEnv(t, env, "TEMPORAL_STORE_USER", "myuser")
	requirePlainEnv(t, env, "TEMPORAL_STORE_DATABASE", "mydb")
}

// --- Deployment: SQL existingSecret without keys (password-only, backward compat) ---

func TestDeploymentSqlExistingSecretNoKeys(t *testing.T) {
	chartPath, err := filepath.Abs("../")
	require.NoError(t, err)
	ns := "temporal-" + strings.ToLower(random.UniqueId())

	opts := &helm.Options{
		SetValues: setValues(sqlBaseValues(), map[string]string{
			"server.config.persistence.default.sql.existingSecret": "my-secret",
		}),
		KubectlOptions:    k8s.NewKubectlOptions("", "", ns),
		BuildDependencies: false,
	}

	out := helm.RenderTemplate(t, opts, chartPath, "temporal", []string{"templates/server-deployment.yaml"})
	var dep appsv1.Deployment
	helm.UnmarshalK8SYaml(t, out, &dep)

	env := dep.Spec.Template.Spec.Containers[0].Env
	// password from secret with default key
	requireSecretRef(t, env, "TEMPORAL_STORE_PASSWORD", "my-secret", "password")
	// connection params still plain values
	requirePlainEnv(t, env, "TEMPORAL_STORE_HOST", "myhost")
	requirePlainEnv(t, env, "TEMPORAL_STORE_PORT", "3306")
	requirePlainEnv(t, env, "TEMPORAL_STORE_USER", "myuser")
	requirePlainEnv(t, env, "TEMPORAL_STORE_DATABASE", "mydb")
}

// --- Deployment: SQL with all existingSecretKeys ---

func TestDeploymentSqlWithExistingSecretKeys(t *testing.T) {
	chartPath, err := filepath.Abs("../")
	require.NoError(t, err)
	ns := "temporal-" + strings.ToLower(random.UniqueId())

	opts := &helm.Options{
		SetValues: setValues(sqlBaseValues(), map[string]string{
			"server.config.persistence.default.sql.existingSecret":              "my-secret",
			"server.config.persistence.default.sql.existingSecretKeys.host":     "s-host",
			"server.config.persistence.default.sql.existingSecretKeys.port":     "s-port",
			"server.config.persistence.default.sql.existingSecretKeys.user":     "s-user",
			"server.config.persistence.default.sql.existingSecretKeys.database": "s-db",
		}),
		KubectlOptions:    k8s.NewKubectlOptions("", "", ns),
		BuildDependencies: false,
	}

	out := helm.RenderTemplate(t, opts, chartPath, "temporal", []string{"templates/server-deployment.yaml"})
	var dep appsv1.Deployment
	helm.UnmarshalK8SYaml(t, out, &dep)

	env := dep.Spec.Template.Spec.Containers[0].Env
	requireSecretRef(t, env, "TEMPORAL_STORE_HOST", "my-secret", "s-host")
	requireSecretRef(t, env, "TEMPORAL_STORE_PORT", "my-secret", "s-port")
	requireSecretRef(t, env, "TEMPORAL_STORE_USER", "my-secret", "s-user")
	requireSecretRef(t, env, "TEMPORAL_STORE_DATABASE", "my-secret", "s-db")
}

// --- Deployment: SQL partial existingSecretKeys ---

func TestDeploymentSqlPartialExistingSecretKeys(t *testing.T) {
	chartPath, err := filepath.Abs("../")
	require.NoError(t, err)
	ns := "temporal-" + strings.ToLower(random.UniqueId())

	opts := &helm.Options{
		SetValues: setValues(sqlBaseValues(), map[string]string{
			"server.config.persistence.default.sql.existingSecret":          "my-secret",
			"server.config.persistence.default.sql.existingSecretKeys.host": "s-host",
		}),
		KubectlOptions:    k8s.NewKubectlOptions("", "", ns),
		BuildDependencies: false,
	}

	out := helm.RenderTemplate(t, opts, chartPath, "temporal", []string{"templates/server-deployment.yaml"})
	var dep appsv1.Deployment
	helm.UnmarshalK8SYaml(t, out, &dep)

	env := dep.Spec.Template.Spec.Containers[0].Env
	requireSecretRef(t, env, "TEMPORAL_STORE_HOST", "my-secret", "s-host")
	requirePlainEnv(t, env, "TEMPORAL_STORE_PORT", "3306")
	requirePlainEnv(t, env, "TEMPORAL_STORE_USER", "myuser")
	requirePlainEnv(t, env, "TEMPORAL_STORE_DATABASE", "mydb")
}

// --- Deployment: SQL password key override ---

func TestDeploymentSqlPasswordKeyOverride(t *testing.T) {
	chartPath, err := filepath.Abs("../")
	require.NoError(t, err)
	ns := "temporal-" + strings.ToLower(random.UniqueId())

	opts := &helm.Options{
		SetValues: setValues(sqlBaseValues(), map[string]string{
			"server.config.persistence.default.sql.existingSecret":                "my-secret",
			"server.config.persistence.default.sql.existingSecretKeys.password":   "my-pwd-key",
		}),
		KubectlOptions:    k8s.NewKubectlOptions("", "", ns),
		BuildDependencies: false,
	}

	out := helm.RenderTemplate(t, opts, chartPath, "temporal", []string{"templates/server-deployment.yaml"})
	var dep appsv1.Deployment
	helm.UnmarshalK8SYaml(t, out, &dep)

	env := dep.Spec.Template.Spec.Containers[0].Env
	requireSecretRef(t, env, "TEMPORAL_STORE_PASSWORD", "my-secret", "my-pwd-key")
}

// --- Deployment: Cassandra backward compat ---

func TestDeploymentCassandraNoExistingSecretKeys(t *testing.T) {
	chartPath, err := filepath.Abs("../")
	require.NoError(t, err)
	ns := "temporal-" + strings.ToLower(random.UniqueId())

	opts := &helm.Options{
		SetValues: map[string]string{
			"server.config.persistence.default.cassandra.hosts[0]": "casshost",
			"server.config.persistence.default.cassandra.port":     "9042",
		},
		KubectlOptions:    k8s.NewKubectlOptions("", "", ns),
		BuildDependencies: false,
	}

	out := helm.RenderTemplate(t, opts, chartPath, "temporal", []string{"templates/server-deployment.yaml"})
	var dep appsv1.Deployment
	helm.UnmarshalK8SYaml(t, out, &dep)

	env := dep.Spec.Template.Spec.Containers[0].Env
	requirePlainEnv(t, env, "TEMPORAL_STORE_HOSTS", "casshost")
	requirePlainEnv(t, env, "TEMPORAL_STORE_PORT", "9042")
	requirePlainEnv(t, env, "TEMPORAL_STORE_USER", "user")
	requirePlainEnv(t, env, "TEMPORAL_STORE_KEYSPACE", "temporal")
}

// --- Deployment: Cassandra with existingSecretKeys ---

func TestDeploymentCassandraWithExistingSecretKeys(t *testing.T) {
	chartPath, err := filepath.Abs("../")
	require.NoError(t, err)
	ns := "temporal-" + strings.ToLower(random.UniqueId())

	opts := &helm.Options{
		SetValues: map[string]string{
			"server.config.persistence.default.cassandra.hosts[0]":                "casshost",
			"server.config.persistence.default.cassandra.existingSecret":          "cass-secret",
			"server.config.persistence.default.cassandra.existingSecretKeys.hosts":    "s-hosts",
			"server.config.persistence.default.cassandra.existingSecretKeys.port":     "s-port",
			"server.config.persistence.default.cassandra.existingSecretKeys.user":     "s-user",
			"server.config.persistence.default.cassandra.existingSecretKeys.keyspace": "s-ks",
		},
		KubectlOptions:    k8s.NewKubectlOptions("", "", ns),
		BuildDependencies: false,
	}

	out := helm.RenderTemplate(t, opts, chartPath, "temporal", []string{"templates/server-deployment.yaml"})
	var dep appsv1.Deployment
	helm.UnmarshalK8SYaml(t, out, &dep)

	env := dep.Spec.Template.Spec.Containers[0].Env
	requireSecretRef(t, env, "TEMPORAL_STORE_HOSTS", "cass-secret", "s-hosts")
	requireSecretRef(t, env, "TEMPORAL_STORE_PORT", "cass-secret", "s-port")
	requireSecretRef(t, env, "TEMPORAL_STORE_USER", "cass-secret", "s-user")
	requireSecretRef(t, env, "TEMPORAL_STORE_KEYSPACE", "cass-secret", "s-ks")
}

// --- Deployment: Cassandra password key override ---

func TestDeploymentCassandraPasswordKeyOverride(t *testing.T) {
	chartPath, err := filepath.Abs("../")
	require.NoError(t, err)
	ns := "temporal-" + strings.ToLower(random.UniqueId())

	opts := &helm.Options{
		SetValues: map[string]string{
			"server.config.persistence.default.cassandra.hosts[0]":                    "casshost",
			"server.config.persistence.default.cassandra.existingSecret":              "cass-secret",
			"server.config.persistence.default.cassandra.existingSecretKeys.password": "my-pwd-key",
		},
		KubectlOptions:    k8s.NewKubectlOptions("", "", ns),
		BuildDependencies: false,
	}

	out := helm.RenderTemplate(t, opts, chartPath, "temporal", []string{"templates/server-deployment.yaml"})
	var dep appsv1.Deployment
	helm.UnmarshalK8SYaml(t, out, &dep)

	env := dep.Spec.Template.Spec.Containers[0].Env
	requireSecretRef(t, env, "TEMPORAL_STORE_PASSWORD", "cass-secret", "my-pwd-key")
}

// --- Deployment: Visibility SQL with existingSecretKeys ---

func TestDeploymentVisibilitySqlWithExistingSecretKeys(t *testing.T) {
	chartPath, err := filepath.Abs("../")
	require.NoError(t, err)
	ns := "temporal-" + strings.ToLower(random.UniqueId())

	opts := &helm.Options{
		SetValues: setValues(sqlBaseValues(), map[string]string{
			"server.config.persistence.visibility.sql.existingSecret":              "vis-secret",
			"server.config.persistence.visibility.sql.existingSecretKeys.host":     "v-host",
			"server.config.persistence.visibility.sql.existingSecretKeys.port":     "v-port",
			"server.config.persistence.visibility.sql.existingSecretKeys.user":     "v-user",
			"server.config.persistence.visibility.sql.existingSecretKeys.database": "v-db",
		}),
		KubectlOptions:    k8s.NewKubectlOptions("", "", ns),
		BuildDependencies: false,
	}

	out := helm.RenderTemplate(t, opts, chartPath, "temporal", []string{"templates/server-deployment.yaml"})
	var dep appsv1.Deployment
	helm.UnmarshalK8SYaml(t, out, &dep)

	env := dep.Spec.Template.Spec.Containers[0].Env
	requireSecretRef(t, env, "TEMPORAL_VISIBILITY_STORE_HOST", "vis-secret", "v-host")
	requireSecretRef(t, env, "TEMPORAL_VISIBILITY_STORE_PORT", "vis-secret", "v-port")
	requireSecretRef(t, env, "TEMPORAL_VISIBILITY_STORE_USER", "vis-secret", "v-user")
	requireSecretRef(t, env, "TEMPORAL_VISIBILITY_STORE_DATABASE", "vis-secret", "v-db")
}

// --- Job: SQL backward compat ---

func TestJobSqlNoExistingSecretKeys(t *testing.T) {
	chartPath, err := filepath.Abs("../")
	require.NoError(t, err)
	ns := "temporal-" + strings.ToLower(random.UniqueId())

	opts := &helm.Options{
		SetValues:         sqlBaseValues(),
		KubectlOptions:    k8s.NewKubectlOptions("", "", ns),
		BuildDependencies: false,
	}

	out := helm.RenderTemplate(t, opts, chartPath, "temporal", []string{"templates/server-job.yaml"})
	var job batchv1.Job
	helm.UnmarshalK8SYaml(t, out, &job)

	c := findInitContainer(job.Spec.Template.Spec.InitContainers, "create-default-store")
	require.NotNil(t, c)

	requirePlainEnv(t, c.Env, "SQL_HOST", "myhost")
	requirePlainEnv(t, c.Env, "SQL_PORT", "3306")
	requirePlainEnv(t, c.Env, "SQL_USER", "myuser")
	requirePlainEnv(t, c.Env, "SQL_DATABASE", "mydb")
}

// --- Job: SQL with existingSecretKeys ---

func TestJobSqlWithExistingSecretKeys(t *testing.T) {
	chartPath, err := filepath.Abs("../")
	require.NoError(t, err)
	ns := "temporal-" + strings.ToLower(random.UniqueId())

	opts := &helm.Options{
		SetValues: setValues(sqlBaseValues(), map[string]string{
			"server.config.persistence.default.sql.existingSecret":              "my-secret",
			"server.config.persistence.default.sql.existingSecretKeys.host":     "s-host",
			"server.config.persistence.default.sql.existingSecretKeys.port":     "s-port",
			"server.config.persistence.default.sql.existingSecretKeys.user":     "s-user",
			"server.config.persistence.default.sql.existingSecretKeys.database": "s-db",
		}),
		KubectlOptions:    k8s.NewKubectlOptions("", "", ns),
		BuildDependencies: false,
	}

	out := helm.RenderTemplate(t, opts, chartPath, "temporal", []string{"templates/server-job.yaml"})
	var job batchv1.Job
	helm.UnmarshalK8SYaml(t, out, &job)

	c := findInitContainer(job.Spec.Template.Spec.InitContainers, "create-default-store")
	require.NotNil(t, c)

	requireSecretRef(t, c.Env, "SQL_HOST", "my-secret", "s-host")
	requireSecretRef(t, c.Env, "SQL_PORT", "my-secret", "s-port")
	requireSecretRef(t, c.Env, "SQL_USER", "my-secret", "s-user")
	requireSecretRef(t, c.Env, "SQL_DATABASE", "my-secret", "s-db")
}

// --- Job: Cassandra with existingSecretKeys ---

func TestJobCassandraWithExistingSecretKeys(t *testing.T) {
	chartPath, err := filepath.Abs("../")
	require.NoError(t, err)
	ns := "temporal-" + strings.ToLower(random.UniqueId())

	opts := &helm.Options{
		SetValues: map[string]string{
			"server.config.persistence.default.cassandra.hosts[0]":                    "casshost",
			"server.config.persistence.default.cassandra.existingSecret":              "cass-secret",
			"server.config.persistence.default.cassandra.existingSecretKeys.hosts":    "s-hosts",
			"server.config.persistence.default.cassandra.existingSecretKeys.port":     "s-port",
			"server.config.persistence.default.cassandra.existingSecretKeys.user":     "s-user",
			"server.config.persistence.default.cassandra.existingSecretKeys.keyspace": "s-ks",
		},
		KubectlOptions:    k8s.NewKubectlOptions("", "", ns),
		BuildDependencies: false,
	}

	out := helm.RenderTemplate(t, opts, chartPath, "temporal", []string{"templates/server-job.yaml"})
	var job batchv1.Job
	helm.UnmarshalK8SYaml(t, out, &job)

	c := findInitContainer(job.Spec.Template.Spec.InitContainers, "create-default-store")
	require.NotNil(t, c)

	requireSecretRef(t, c.Env, "CASSANDRA_HOST", "cass-secret", "s-hosts")
	requireSecretRef(t, c.Env, "CASSANDRA_PORT", "cass-secret", "s-port")
	requireSecretRef(t, c.Env, "CASSANDRA_USER", "cass-secret", "s-user")
	requireSecretRef(t, c.Env, "CASSANDRA_KEYSPACE", "cass-secret", "s-ks")
}

// --- Configmap: SQL uses env var substitution ---

func TestConfigmapSqlEnvVarSubstitution(t *testing.T) {
	chartPath, err := filepath.Abs("../")
	require.NoError(t, err)
	ns := "temporal-" + strings.ToLower(random.UniqueId())

	opts := &helm.Options{
		SetValues:         sqlBaseValues(),
		KubectlOptions:    k8s.NewKubectlOptions("", "", ns),
		BuildDependencies: false,
	}

	out := helm.RenderTemplate(t, opts, chartPath, "temporal", []string{"templates/server-configmap.yaml"})

	assert.Contains(t, out, "{{ .Env.TEMPORAL_STORE_DATABASE | quote }}")
	assert.Contains(t, out, "{{ .Env.TEMPORAL_STORE_HOST }}")
	assert.Contains(t, out, "{{ .Env.TEMPORAL_STORE_PORT }}")
	assert.Contains(t, out, "{{ .Env.TEMPORAL_STORE_USER }}")
}

// --- Configmap: Cassandra uses env var substitution ---

func TestConfigmapCassandraEnvVarSubstitution(t *testing.T) {
	chartPath, err := filepath.Abs("../")
	require.NoError(t, err)
	ns := "temporal-" + strings.ToLower(random.UniqueId())

	opts := &helm.Options{
		KubectlOptions:    k8s.NewKubectlOptions("", "", ns),
		BuildDependencies: false,
	}

	out := helm.RenderTemplate(t, opts, chartPath, "temporal", []string{"templates/server-configmap.yaml"})

	assert.Contains(t, out, "{{ .Env.TEMPORAL_STORE_HOSTS }}")
	assert.Contains(t, out, "{{ .Env.TEMPORAL_STORE_PORT }}")
	assert.Contains(t, out, "{{ .Env.TEMPORAL_STORE_USER }}")
	assert.Contains(t, out, "{{ .Env.TEMPORAL_STORE_KEYSPACE }}")
}