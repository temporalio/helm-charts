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


func TestTemplateServerEntrypointScript(t *testing.T) {
	helmChartPath, err := filepath.Abs("../")
	require.NoError(t, err)
	
	namespaceName := "temporal-" + strings.ToLower(random.UniqueId())
	
	options := &helm.Options{
		SetValues: map[string]string{
			"server.useEntrypointScript": "true",
		},
		KubectlOptions:    k8s.NewKubectlOptions("", "", namespaceName),
		BuildDependencies: true,
	}
	
	output := helm.RenderTemplate(t, options, helmChartPath, "temporal", []string{"templates/server-entrypoint-script.yaml"})
	
	require.Contains(t, output, "ConfigMap")
	require.Contains(t, output, "entrypoint.sh")
	require.Contains(t, output, "dockerize")
	require.Contains(t, output, "temporal-server")
}

func TestTemplateServerDeploymentWithEntrypointScript(t *testing.T) {
	helmChartPath, err := filepath.Abs("../")
	require.NoError(t, err)
	
	namespaceName := "temporal-" + strings.ToLower(random.UniqueId())
	
	testCases := []struct {
		name              string
		configMapsToMount string
		expectDockerize   bool
		expectSprig       bool
	}{
		{"both configs", "both", true, true},
		{"dockerize only", "dockerize", true, false},
		{"sprig only", "sprig", false, true},
	}
	
	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			var deployment appsv1.Deployment
			
			options := &helm.Options{
				SetValues: map[string]string{
					"server.useEntrypointScript": "true",
					"server.configMapsToMount":   tc.configMapsToMount,
				},
				KubectlOptions:    k8s.NewKubectlOptions("", "", namespaceName),
				BuildDependencies: true,
			}
			
			output := helm.RenderTemplate(t, options, helmChartPath, "temporal", []string{"templates/server-deployment.yaml"})
			helm.UnmarshalK8SYaml(t, output, &deployment)
			
			// Verify command override
			require.Equal(t, []string{"/entrypoint/entrypoint.sh"}, deployment.Spec.Template.Spec.Containers[0].Command)
			
			// Verify volume configuration
			volumeNames := make([]string, len(deployment.Spec.Template.Spec.Volumes))
			for i, vol := range deployment.Spec.Template.Spec.Volumes {
				volumeNames[i] = vol.Name
			}
			
			require.Contains(t, volumeNames, "entrypoint-script")
			require.Contains(t, volumeNames, "config-processed")
			
			if tc.expectDockerize {
				require.Contains(t, volumeNames, "config-dockerize")
			} else {
				require.NotContains(t, volumeNames, "config-dockerize")
			}

			if tc.expectSprig {
				require.Contains(t, volumeNames, "config-sprig")
			} else {
				require.NotContains(t, volumeNames, "config-sprig")
			}
		})
	}
}
