package test

import (
	"path/filepath"
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/helm"
	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/stretchr/testify/require"
	appsv1 "k8s.io/api/apps/v1"
)

func TestTemplateServerServiceDefault(t *testing.T) {
	// t.Parallel()

	helmChartPath, err := filepath.Abs("../")
	releaseName := "temporal"
	require.NoError(t, err)

	namespaceName := "temporal-" + strings.ToLower(random.UniqueId())

	var deployment appsv1.Deployment

	options := &helm.Options{
		KubectlOptions:    k8s.NewKubectlOptions("", "", namespaceName),
		BuildDependencies: true,
	}

	output := helm.RenderTemplate(t, options, helmChartPath, releaseName, []string{"templates/server-service.yaml"})

	helm.UnmarshalK8SYaml(t, output, &deployment)
}

func TestTemplateServerServiceFrontendClusterIP(t *testing.T) {
	// t.Parallel()

	helmChartPath, err := filepath.Abs("../")
	releaseName := "temporal"
	require.NoError(t, err)

	namespaceName := "temporal-" + strings.ToLower(random.UniqueId())

	var deployment appsv1.Deployment

	options := &helm.Options{
		SetValues: map[string]string{
			"frontend.service.clusterIP": "None",
		},
		KubectlOptions:    k8s.NewKubectlOptions("", "", namespaceName),
		BuildDependencies: true,
	}

	output := helm.RenderTemplate(t, options, helmChartPath, releaseName, []string{"templates/server-service.yaml"})

	helm.UnmarshalK8SYaml(t, output, &deployment)
}
