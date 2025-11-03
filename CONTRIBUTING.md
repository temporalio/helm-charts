# Contributing to Temporal Helm Charts

Thank you for your interest in contributing to the Temporal Helm Charts! This document explains our process and expectations for community contributions.

## Encouraging Contributions

We actively encourage contributions in the form of issues and pull requests (PRs). Whether you've found a bug, want to request a feature, or contribute other types of improvements, we welcome all participation. Your help can improve the Temporal Helm Charts for everyone.

### Opening Issues

If you encounter a bug, have an idea for improving the current functionality, or would like to request a new feature, please begin by opening an issue. When doing so, ensure that you:

- Provide a clear description of the current and desired behavior
- Include any relevant logs, error messages, or reproduction steps (if applicable)
- Offer suggestions on how to solve the problem you report, if possible

### Submitting Pull Requests (PRs)

We welcome your pull request. Before submitting, please ensure that your PR:

- Clearly describes your changes, including the steps you followed to test them
- Follows [Helm Charts best practices](https://helm.sh/docs/topics/chart_best_practices/)
- Documents any known issues or limitations with your implementation
- If possible, includes automated tests to help us validate the changes 
  and prevent future regressions. While this is not strictly required, 
  it substantially reduces the effort required to evaluate the PR, and
  we will prioritize PRs that provide tests over those that do not.

Feel free to submit a draft PR early if you need feedback or assistance during the development process. This can help identify potential improvements or issues early on.

Note: When you submit your first PR, you will be asked to sign the [Temporal Contributor License Agreement (CLA)](https://cla-assistant.io/temporalio/helm-charts) before we merge your PR.

## Types of Changes We Accept

We prioritize and accept changes that enable customization required for Temporal to run on specific Kubernetes platforms or to meet security requirements. Examples of acceptable changes include:

- **Security configurations**: Adding or enhancing security contexts, pod security policies, network policies, or other security-related Kubernetes resources
- **Credential management**: Supporting credential retrieval from Kubernetes secrets (e.g., fetching database credentials from a secret instead of a ConfigMap)
- **Platform-specific requirements**: Adaptations needed for specific Kubernetes distributions, cloud providers, or managed Kubernetes services
- **Service account and RBAC customization**: Enhancements to service accounts, roles, and role bindings to meet organizational security policies
- **Resource management**: Customizations to resource limits, requests, or scheduling constraints required by platform policies
- **Monitoring and observability**: Integration with platform-specific monitoring, logging, or observability solutions
- **CI/CD system compatibility**: Changes that enable the chart to work with GitOps tools and CI/CD systems (e.g., ArgoCD, Flux). These changes must be configuration-driven and optional to preserve a good manual installation experience
- **Testing infrastructure and reliability**: Improvements to the testing infrastructure or changes that make the chart more reliable and robust

### Changes We Don't Accept

To keep the charts focused and maintainable, we generally do not accept:

- **Persistence backend sub-charts**: We are removing the use of sub-charts for persistence backends (e.g., MySQL, PostgreSQL, Cassandra). Users should configure Temporal to connect to existing database infrastructure rather than deploying databases via sub-charts.
- **Integration with unsupported technologies**: Changes required to integrate Temporal with technologies that Temporal does not support. Such changes will only be accepted if they provide benefits in a wider context beyond the specific integration.
- **Feature additions unrelated to platform compatibility or security**: New features that don't address Kubernetes platform requirements or security needs
- **Cosmetic or stylistic changes**: UI, naming, or formatting changes that don't affect functionality or configurability


## Issues and Pull Requests Lifecycle

- **Issues**: This is an open source project. Issues can be resolved by any community member. The maintainers of this project do triage issues regularly to ensure the issue is clear and tagged appropriately. If more information is needed, we will ask for further clarification. We encourage discussion to clarify the problem or refine solutions. 
  
- **Pull Requests**: Once a PR is submitted, it will be reviewed by the maintainers. We will provide feedback, and may ask the contributor to make changes. Once all feedback is addressed and the PR passes the necessary tests, we will merge it. Please note that complex changes or large PRs may take longer to review. Again, providing automated tests for your PR will help to ensure that we prioritize it for review.

Releases for the Helm Charts are not triggered automatically, the Temporal team will periodically do releases.

## Expectations for Reviews and Issue Triage

While we strive to review issues/PRs and merge contributions as quickly as possible, we operate on a **best-effort basis**. There are no guarantees on review times, and no service level agreements (SLAs) are provided. We appreciate your patience and understanding as maintainers work through the queue of issues and pull requests.


## Getting Help

If you would like to discuss the Temporal Helm Charts or seek advice about a potential improvement, feel free to join [Temporal's public Slack](https://t.mp/slack). The Temporal team that works on the charts and the contributor community hang out in the `#helm-charts` channel.

## Code of Conduct

By participating in this project you agree to abide by the [Temporal Code of Conduct](https://temporal.io/code-of-conduct).

