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
			"server.frontend.deploymentAnnotations.five": "[{\"test\":\"success\"}]",
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
	require.Equal(t, "[{\"test\":\"success\"}]", deployment.ObjectMeta.Annotations["five"])
	require.Equal(t, "zero", deployment.ObjectMeta.Annotations["zero"])
	require.Equal(t, "zero", deployment.Spec.Template.ObjectMeta.Annotations["zero"])
}

func TestTemplateServerDeploymentLabels(t *testing.T) {
	// t.Parallel()

	helmChartPath, err := filepath.Abs("../")
	releaseName := "temporal"
	require.NoError(t, err)

	namespaceName := "temporal-" + strings.ToLower(random.UniqueId())

	var deployment appsv1.Deployment

	options := &helm.Options{
		SetValues: map[string]string{
			"server.frontend.deploymentLabels.one":  "three",
			"server.frontend.deploymentLabels.four": "four",
			"server.frontend.deploymentLabels.five": "[{\"test\":\"success\"}]",
			"server.deploymentLabels.one":           "one",
			"server.deploymentLabels.two":           "two",
			"additionalLabels.zero":                 "zero",
		},
		KubectlOptions:    k8s.NewKubectlOptions("", "", namespaceName),
		BuildDependencies: true,
	}

	output := helm.RenderTemplate(t, options, helmChartPath, releaseName, []string{"templates/server-deployment.yaml"})

	helm.UnmarshalK8SYaml(t, output, &deployment)

	require.Equal(t, "three", deployment.ObjectMeta.Labels["one"])
	require.Equal(t, "two", deployment.ObjectMeta.Labels["two"])
	require.Equal(t, "four", deployment.ObjectMeta.Labels["four"])
	require.Equal(t, "[{\"test\":\"success\"}]", deployment.ObjectMeta.Labels["five"])
	require.Equal(t, "zero", deployment.ObjectMeta.Labels["zero"])
	require.Equal(t, "zero", deployment.Spec.Template.ObjectMeta.Labels["zero"])
}

func TestTemplateServerEntrypointScriptConfigMap(t *testing.T) {
	// t.Parallel()

	helmChartPath, err := filepath.Abs("../")
	releaseName := "temporal"
	require.NoError(t, err)

	namespaceName := "temporal-" + strings.ToLower(random.UniqueId())

	options := &helm.Options{
		SetValues: map[string]string{
			"server.useEntrypointScript": "true",
		},
		KubectlOptions:    k8s.NewKubectlOptions("", "", namespaceName),
		BuildDependencies: true,
	}

	output := helm.RenderTemplate(t, options, helmChartPath, releaseName, []string{"templates/server-entrypoint-script.yaml"})

	// Verify the output contains expected script elements
	require.Contains(t, output, "ConfigMap")
	require.Contains(t, output, "entrypoint.sh")
	require.Contains(t, output, "dockerize")
	require.Contains(t, output, "CONFIG_TYPE")
}

func TestTemplateServerDeploymentWithEntrypointScript(t *testing.T) {
	// t.Parallel()

	helmChartPath, err := filepath.Abs("../")
	releaseName := "temporal"
	require.NoError(t, err)

	namespaceName := "temporal-" + strings.ToLower(random.UniqueId())

	var deployment appsv1.Deployment

	options := &helm.Options{
		SetValues: map[string]string{
			"server.useEntrypointScript": "true",
			"server.configMapsToMount":   "both",
		},
		KubectlOptions:    k8s.NewKubectlOptions("", "", namespaceName),
		BuildDependencies: true,
	}

	output := helm.RenderTemplate(t, options, helmChartPath, releaseName, []string{"templates/server-deployment.yaml"})

	helm.UnmarshalK8SYaml(t, output, &deployment)

	// Verify command override
	require.Equal(t, []string{"/entrypoint/entrypoint.sh"}, deployment.Spec.Template.Spec.Containers[0].Command)

	// Verify volumes include entrypoint-script
	volumeNames := make([]string, len(deployment.Spec.Template.Spec.Volumes))
	for i, vol := range deployment.Spec.Template.Spec.Volumes {
		volumeNames[i] = vol.Name
	}
	require.Contains(t, volumeNames, "entrypoint-script")
	require.Contains(t, volumeNames, "config-legacy")
	require.Contains(t, volumeNames, "config-modern")
	require.Contains(t, volumeNames, "config-processed")

	// Verify volume mounts
	volumeMountNames := make([]string, len(deployment.Spec.Template.Spec.Containers[0].VolumeMounts))
	for i, mount := range deployment.Spec.Template.Spec.Containers[0].VolumeMounts {
		volumeMountNames[i] = mount.Name
	}
	require.Contains(t, volumeMountNames, "entrypoint-script")
	require.Contains(t, volumeMountNames, "config-legacy")
	require.Contains(t, volumeMountNames, "config-modern")
	require.Contains(t, volumeMountNames, "config-processed")
}

func TestTemplateServerDeploymentConfigMapsToMountLegacy(t *testing.T) {
	// t.Parallel()

	helmChartPath, err := filepath.Abs("../")
	releaseName := "temporal"
	require.NoError(t, err)

	namespaceName := "temporal-" + strings.ToLower(random.UniqueId())

	var deployment appsv1.Deployment

	options := &helm.Options{
		SetValues: map[string]string{
			"server.useEntrypointScript": "true",
			"server.configMapsToMount":   "legacy",
		},
		KubectlOptions:    k8s.NewKubectlOptions("", "", namespaceName),
		BuildDependencies: true,
	}

	output := helm.RenderTemplate(t, options, helmChartPath, releaseName, []string{"templates/server-deployment.yaml"})

	helm.UnmarshalK8SYaml(t, output, &deployment)

	// Verify volumes only include legacy config
	volumeNames := make([]string, len(deployment.Spec.Template.Spec.Volumes))
	for i, vol := range deployment.Spec.Template.Spec.Volumes {
		volumeNames[i] = vol.Name
	}
	require.Contains(t, volumeNames, "config-legacy")
	require.NotContains(t, volumeNames, "config-modern")
}

func TestTemplateServerDeploymentConfigMapsToMountModern(t *testing.T) {
	// t.Parallel()

	helmChartPath, err := filepath.Abs("../")
	releaseName := "temporal"
	require.NoError(t, err)

	namespaceName := "temporal-" + strings.ToLower(random.UniqueId())

	var deployment appsv1.Deployment

	options := &helm.Options{
		SetValues: map[string]string{
			"server.useEntrypointScript": "true",
			"server.configMapsToMount":   "modern",
		},
		KubectlOptions:    k8s.NewKubectlOptions("", "", namespaceName),
		BuildDependencies: true,
	}

	output := helm.RenderTemplate(t, options, helmChartPath, releaseName, []string{"templates/server-deployment.yaml"})

	helm.UnmarshalK8SYaml(t, output, &deployment)

	// Verify volumes only include modern config
	volumeNames := make([]string, len(deployment.Spec.Template.Spec.Volumes))
	for i, vol := range deployment.Spec.Template.Spec.Volumes {
		volumeNames[i] = vol.Name
	}
	require.Contains(t, volumeNames, "config-modern")
	require.NotContains(t, volumeNames, "config-legacy")
}
