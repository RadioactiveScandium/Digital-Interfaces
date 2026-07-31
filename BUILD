# Load specifically from the sh_binary.bzl definition file
load("@rules_shell//shell:sh_binary.bzl", "sh_binary")

sh_binary(
    name = "print_readme",
    srcs = ["print_readme.sh"],
    data = ["README.md"],
)
