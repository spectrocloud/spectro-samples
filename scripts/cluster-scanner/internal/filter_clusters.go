package internal

import (
	"strings"

	"github.com/spectrocloud/palette-sdk-go/api/models"
)

// ParseCloudTypes splits a comma-separated list of cloud types, such as the value of the
// SCAN_CLOUD_TYPES environment variable, into lowercase cloud types. Empty entries are ignored.
func ParseCloudTypes(value string) []string {
	var cloudTypes []string
	for _, cloudType := range strings.Split(value, ",") {
		cloudType = strings.ToLower(strings.TrimSpace(cloudType))
		if cloudType != "" {
			cloudTypes = append(cloudTypes, cloudType)
		}
	}
	return cloudTypes
}

// FilterClustersByCloudType returns the clusters whose cloud type is in cloudTypes, ignoring case.
// If cloudTypes is empty, it returns every cluster, so the scan covers all cloud types by default.
// Clusters without a cloud type are left out when a filter is set.
func FilterClustersByCloudType(clusters []*models.V1SpectroClusterSummary, cloudTypes []string) []*models.V1SpectroClusterSummary {
	if len(cloudTypes) == 0 {
		return clusters
	}

	allowed := make(map[string]bool, len(cloudTypes))
	for _, cloudType := range cloudTypes {
		allowed[strings.ToLower(cloudType)] = true
	}

	var filtered []*models.V1SpectroClusterSummary
	for _, cluster := range clusters {
		if cluster == nil || cluster.SpecSummary == nil || cluster.SpecSummary.CloudConfig == nil {
			continue
		}
		if allowed[strings.ToLower(cluster.SpecSummary.CloudConfig.CloudType)] {
			filtered = append(filtered, cluster)
		}
	}
	return filtered
}
