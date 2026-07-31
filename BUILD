# Load specifically from the sh_binary.bzl definition file
load("@rules_shell//shell:sh_binary.bzl", "sh_binary")

# Replaces the sh_binary entirely so no extra .sh script is needed
genrule(
    name = "print_readme",
    srcs = ["README.md"],
    outs = ["readme_output.log"],
    cmd = "cat $(location README.md) && touch $@",
)
