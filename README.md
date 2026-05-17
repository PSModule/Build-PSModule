# Build-PSModule

This GitHub Action is a part of the [PSModule framework](https://github.com/PSModule).

It compiles a PowerShell module from a `src/` folder and produces an artifact that is ready to test and ship.

## What's new

`Build-PSModule` now accepts `Version` and `Prerelease` inputs that are stamped directly into the built manifest, so
the artifact uploaded for the test stages is the same artifact that ultimately gets published. When `Version` is not
provided, the placeholder `999.0.0` is used so local builds still produce a valid manifest.

This pairs with [`PSModule/Resolve-PSModuleVersion`](https://github.com/PSModule/Resolve-PSModuleVersion) and the
v3.x rewrite of [`PSModule/Publish-PSModule`](https://github.com/PSModule/Publish-PSModule). See
[PSModule/Process-PSModule#326](https://github.com/PSModule/Process-PSModule/issues/326) for context.

## Inputs

| Name               | Description                                                                                                          | Required | Default  |
| ------------------ | -------------------------------------------------------------------------------------------------------------------- | -------- | -------- |
| `Name`             | Name of the module to build. Defaults to the repository name.                                                        | No       |          |
| `Version`          | `Major.Minor.Patch` version to stamp into the built manifest. When empty, `999.0.0` is used as a local-build placeholder. | No       | `''`     |
| `Prerelease`       | Optional prerelease tag (for example `feature001`). When set, it is written to `PrivateData.PSData.Prerelease`.       | No       | `''`     |
| `ArtifactName`     | Name of the artifact uploaded by the action.                                                                          | No       | `module` |
| `WorkingDirectory` | The working directory where the script will run from.                                                                 | No       | `.`      |

## Outputs

| Name                     | Description                              |
| ------------------------ | ---------------------------------------- |
| `ModuleOutputFolderPath` | Local path to the built module folder.   |
