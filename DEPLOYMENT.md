# Kubernetes deployment

The manual GitHub Actions workflow at `.github/workflows/2.1.-build-and-deploy-pr.yaml` follows the MediequiposGT PR deployment pattern. It builds an architecture-specific nginx image, pushes it to Docker Hub, copies the Kubernetes resources to the PR server, performs a rolling deployment, and verifies the deployed version and every redirect.

## Redirects

`links.txt` is the source of truth. Each non-comment line contains a path and destination URL separated by one space:

```text
/source-path https://destination.example/path
```

During the image build, `scripts/generate-nginx-config.sh` creates exact nginx routes for both `/source-path` and `/source-path/`. They return HTTP `302` with these headers:

```text
Cache-Control: no-store, no-cache, must-revalidate, max-age=0
Pragma: no-cache
Expires: 0
```

The temporary redirect and explicit cache headers allow a destination to change without Safari retaining an old redirect.

`/enlace/congreso-dermapedia` is intentionally not part of `links.txt`. It uses the newer Safari/Data Saver workaround: static HTML stored as `public/enlace/congreso-dermapedia/index.php`. nginx serves that specific file as `text/html` with no-cache headers, without installing or executing PHP. Every other PHP-like path returns `404`.

## Deployment version and sanity check

The deployment version is `${GITHUB_RUN_ID}.${GITHUB_RUN_ATTEMPT}`. `GITHUB_RUN_ID` is a numeric identifier for the repository's workflow run and does not depend on the repository name.

The build writes this value to:

- the `deployment-version` comment in `/index.html`;
- `/version.txt`, served with no-cache headers;
- the unique Docker image tag.

After Kubernetes reports a successful rollout, `scripts/smoke-test.sh` connects directly to the PR server while using `v3soluciones.com` for TLS and ingress routing. It verifies the exact version, the HTML version comment, all redirect destinations, and their no-cache headers. Only then does the workflow report deployment success.

## GitHub configuration

Required Actions secrets:

- `DOCKERHUB_USER`
- `DOCKERHUB_PASS`
- `DEPLOY_PK`

Required Actions variable:

- `KNOWN_HOSTS`

These are the same names used by the MediequiposGT deployment workflow. The PR Kubernetes server is read from `.github/config.json`.
