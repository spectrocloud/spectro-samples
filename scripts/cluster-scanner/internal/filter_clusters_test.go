package internal_test

import (
	"reflect"
	"testing"

	"github.com/spectrocloud/palette-samples/cluster-scanner/internal"
	"github.com/spectrocloud/palette-sdk-go/api/models"
)

func TestParseCloudTypes(t *testing.T) {
	tc := map[string]struct {
		input  string
		output []string
	}{
		"empty value":          {input: "", output: nil},
		"one cloud type":       {input: "aws", output: []string{"aws"}},
		"spaces and uppercase": {input: "aws, EKS ,azure", output: []string{"aws", "eks", "azure"}},
		"empty entries":        {input: "aws,,gcp,", output: []string{"aws", "gcp"}},
	}

	for key, value := range tc {
		t.Run(key, func(t *testing.T) {
			got := internal.ParseCloudTypes(value.input)
			if !reflect.DeepEqual(got, value.output) {
				t.Errorf("Got %v, want %v", got, value.output)
			}
		})
	}
}

func TestFilterClustersByCloudType(t *testing.T) {
	createSummary := func(name string, cloudType string) *models.V1SpectroClusterSummary {
		return &models.V1SpectroClusterSummary{
			Metadata: &models.V1ObjectMeta{Name: name},
			SpecSummary: &models.V1SpectroClusterSummarySpecSummary{
				CloudConfig: &models.V1CloudConfigMeta{CloudType: cloudType},
			},
		}
	}

	clusters := []*models.V1SpectroClusterSummary{
		createSummary("aws-cluster", "aws"),
		createSummary("eks-cluster", "eks"),
		createSummary("edge-cluster", "edge-native"),
		createSummary("vsphere-cluster", "vsphere"),
		{Metadata: &models.V1ObjectMeta{Name: "no-cloud-config"}},
	}

	tc := map[string]struct {
		cloudTypes []string
		names      []string
	}{
		"no filter keeps every cluster": {
			cloudTypes: nil,
			names:      []string{"aws-cluster", "eks-cluster", "edge-cluster", "vsphere-cluster", "no-cloud-config"},
		},
		"public clouds only": {
			cloudTypes: []string{"aws", "eks", "azure", "aks", "gcp", "gke"},
			names:      []string{"aws-cluster", "eks-cluster"},
		},
		"case does not matter": {
			cloudTypes: []string{"EDGE-NATIVE"},
			names:      []string{"edge-cluster"},
		},
		"no matching cloud type": {
			cloudTypes: []string{"maas"},
			names:      nil,
		},
	}

	for key, value := range tc {
		t.Run(key, func(t *testing.T) {
			var names []string
			for _, cluster := range internal.FilterClustersByCloudType(clusters, value.cloudTypes) {
				names = append(names, cluster.Metadata.Name)
			}
			if !reflect.DeepEqual(names, value.names) {
				t.Errorf("Got %v, want %v", names, value.names)
			}
		})
	}
}
