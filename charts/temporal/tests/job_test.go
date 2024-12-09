package test

import (
	"path/filepath"
	"strings"
	"testing"

	"github.com/stretchr/testify/require"
	batchv1 "k8s.io/api/batch/v1"
	corev1 "k8s.io/api/core/v1"

	"github.com/gruntwork-io/terratest/modules/helm"
	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/gruntwork-io/terratest/modules/random"
)

func TestAdminToolsSqlConnectAttributes(t *testing.T) {
	// t.Parallel()

	helmChartPath, err := filepath.Abs("../")
	releaseName := "temporal"
	require.NoError(t, err)

	namespaceName := "temporal-" + strings.ToLower(random.UniqueId())

	var job batchv1.Job

	options := &helm.Options{
		SetValues: map[string]string{
			"cassandra.enabled":                        "false",
			"mysql.enabled":                            "true",
			"server.config.persistence.default.driver": "sql",
			"server.config.persistence.default.sql.connectAttributes.one": "test",
			"server.config.persistence.default.sql.connectAttributes.two": "3",
		},
		KubectlOptions:    k8s.NewKubectlOptions("", "", namespaceName),
		BuildDependencies: true,
	}

	output := helm.RenderTemplate(t, options, helmChartPath, releaseName, []string{"templates/server-job.yaml"})

	helm.UnmarshalK8SYaml(t, output, &job)

	// Find the container init container "create-default-store"
	var container corev1.Container
	for _, c := range job.Spec.Template.Spec.InitContainers {
		if c.Name == "create-default-store" {
			container = c
			break
		}
	}
	require.NotNil(t, container)

	// Check the environment variables
	require.Contains(t, container.Env, corev1.EnvVar{Name: "SQL_CONNECT_ATTRIBUTES", Value: "one=test&two=3"})
}
