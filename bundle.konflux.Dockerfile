FROM registry.access.redhat.com/ubi9:latest as builder

WORKDIR /operator
COPY . .
RUN dnf install make python3-pip jq -y && pip install yq
# Small makefile that defines a target that exposes the value of a given variable.
RUN echo $'\n\
%.var:\n\
	@echo $($*)\n\
' >printvar.makefile
# Captur the VERSION from the Makefile and replace its references in the bundle's CSV.
# The image pullspec digest should have been already updated with Konflux's nudge PR.
# The only remaining task left is to update the version references in the CSV file.
RUN \
	csv_file="bundle/manifests/orchestrator-operator.clusterserviceversion.yaml" && \
	v=$(make -f printvar.makefile -f Makefile VERSION.var) && \
	yq -Y -i '(.spec.version) = "'$v'"' $csv_file && \
	yq -Y -i '(.metadata.name) = "orchestrator-operator.v'$v'"' $csv_file

FROM scratch

# Core bundle labels.
LABEL operators.operatorframework.io.bundle.mediatype.v1=registry+v1
LABEL operators.operatorframework.io.bundle.manifests.v1=manifests/
LABEL operators.operatorframework.io.bundle.metadata.v1=metadata/
LABEL operators.operatorframework.io.bundle.package.v1=orchestrator-operator
LABEL operators.operatorframework.io.bundle.channels.v1=alpha
LABEL operators.operatorframework.io.metrics.builder=operator-sdk-v1.33.0
LABEL operators.operatorframework.io.metrics.mediatype.v1=metrics+v1
LABEL operators.operatorframework.io.metrics.project_layout=helm.sdk.operatorframework.io/v1

# Labels for operator certification https://redhat-connect.gitbook.io/certified-operator-guide/ocp-deployment/operator-metadata/bundle-directory
LABEL com.redhat.delivery.operator.bundle=true

# This sets the earliest version of OCP where our operator build would show up in the official Red Hat operator catalog.
# vX means "X or later": https://redhat-connect.gitbook.io/certified-operator-guide/ocp-deployment/operator-metadata/bundle-directory/managing-openshift-versions
#
# See EOL schedule: https://docs.engineering.redhat.com/display/SP/Shipping+Operators+to+EOL+OCP+versions
#
LABEL com.redhat.openshift.versions="v4.14"

# Labels for testing.
LABEL operators.operatorframework.io.test.mediatype.v1=scorecard+v1
LABEL operators.operatorframework.io.test.config.v1=tests/scorecard/

# Copy files to locations specified by labels.
COPY --from=builder /operator/bundle/manifests /manifests/
COPY --from=builder /operator/bundle/metadata /metadata/
COPY --from=builder /operator/bundle/tests/scorecard /tests/scorecard/
