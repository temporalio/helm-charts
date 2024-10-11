package test

import (
	"path/filepath"
	"strings"
	"testing"

	"github.com/stretchr/testify/require"
	appsv1 "k8s.io/api/apps/v1"

	"github.com/gruntwork-io/terratest/modules/helm"
	"github.com/gruntwork-io/terratest/modules/k8s"
	"github.com/gruntwork-io/terratest/modules/random"
)

func TestTemplateServerDeploymentDefault(t *testing.T) {
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

	output := helm.RenderTemplate(t, options, helmChartPath, releaseName, []string{"templates/server-deployment.yaml"})

	helm.UnmarshalK8SYaml(t, output, &deployment)
}

func TestTemplateServerDeploymentWhitespace(t *testing.T) {
	// t.Parallel()

	helmChartPath, err := filepath.Abs("../")
	releaseName := "temporal"
	require.NoError(t, err)

	namespaceName := "temporal-" + strings.ToLower(random.UniqueId())

	var deployment appsv1.Deployment

	options := &helm.Options{
		SetValues: map[string]string{
			"server.frontend.podLabels.one": "one",
		},
		KubectlOptions:    k8s.NewKubectlOptions("", "", namespaceName),
		BuildDependencies: true,
	}

	output := helm.RenderTemplate(t, options, helmChartPath, releaseName, []string{"templates/server-deployment.yaml"})

	helm.UnmarshalK8SYaml(t, output, &deployment)

	require.Equal(t, "one", deployment.Spec.Template.ObjectMeta.Labels["one"])

	options = &helm.Options{
		SetValues: map[string]string{
			"server.frontend.podLabels.one": "one",
			"server.frontend.podLabels.two": "two",
		},
		KubectlOptions:    k8s.NewKubectlOptions("", "", namespaceName),
		BuildDependencies: true,
	}

	output = helm.RenderTemplate(t, options, helmChartPath, releaseName, []string{"templates/server-deployment.yaml"})

	helm.UnmarshalK8SYaml(t, output, &deployment)

	require.Equal(t, "one", deployment.Spec.Template.ObjectMeta.Labels["one"])
	require.Equal(t, "two", deployment.Spec.Template.ObjectMeta.Labels["two"])
}

func TestTemplateServerDeploymentMerging(t *testing.T) {
	// t.Parallel()

	helmChartPath, err := filepath.Abs("../")
	releaseName := "temporal"
	require.NoError(t, err)

	namespaceName := "temporal-" + strings.ToLower(random.UniqueId())

	var deployment appsv1.Deployment

	options := &helm.Options{
		SetValues: map[string]string{
			"server.frontend.podLabels.one": "three",
			"server.podLabels.one":          "one",
			"server.podLabels.two":          "two",
		},
		KubectlOptions:    k8s.NewKubectlOptions("", "", namespaceName),
		BuildDependencies: true,
	}

	output := helm.RenderTemplate(t, options, helmChartPath, releaseName, []string{"templates/server-deployment.yaml"})

	helm.UnmarshalK8SYaml(t, output, &deployment)

	require.Equal(t, "three", deployment.Spec.Template.ObjectMeta.Labels["one"])
	require.Equal(t, "two", deployment.Spec.Template.ObjectMeta.Labels["two"])
}

func TestTemplateServerDeploymentAnnotations(t *testing.T) {
	// t.Parallel()

	helmChartPath, err := filepath.Abs("../")
	releaseName := "temporal"
	require.NoError(t, err)

	namespaceName := "temporal-" + strings.ToLower(random.UniqueId())

	var deployment appsv1.Deployment

	options := &helm.Options{
		SetValues: map[string]string{
			"server.frontend.deploymentAnnotations.one":  "three",
			"server.frontend.deploymentAnnotations.four": "four",
			"server.deploymentAnnotations.one":           "one",
			"server.deploymentAnnotations.two":           "two",
			"additionalAnnotations.zero":                 "zero",
		},
		KubectlOptions:    k8s.NewKubectlOptions("", "", namespaceName),
		BuildDependencies: true,
	}

	output := helm.RenderTemplate(t, options, helmChartPath, releaseName, []string{"templates/server-deployment.yaml"})

	helm.UnmarshalK8SYaml(t, output, &deployment)

	require.Equal(t, "three", deployment.ObjectMeta.Annotations["one"])
	require.Equal(t, "two", deployment.ObjectMeta.Annotations["two"])
	require.Equal(t, "four", deployment.ObjectMeta.Annotations["four"])
}
