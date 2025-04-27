variable "cache_settings" {
  default = [
    {
      type = "registry",
      ref = "${image}-cache:cache"
    }
  ]
}

variable "org" { default = "clanktron" }
variable "repo" { default = "blog" }
variable "tag" { default = "latest" }
variable "image" { default = "${org}/${repo}"}
variable "ref" { default = "${image}:${tag}"}

target "default" {
  inherits = ["cache"]
  output = [
    "type=image,name=${ref},mode=max"
  ]
}

target "default-push" {
  inherits = ["default"]
  output = [
    "type=registry,name=${ref}"
  ]
}

target "cache" {
  cache-from = cache_settings
  cache-to = cache_settings
}

target "containers" {
  inherits = ["cache"]
  target = "production"
  platforms = [
    "linux/arm64",
    "linux/amd64",
    "linux/arm/v7",
    "linux/riscv64"
  ]
  output = [
    "type=registry,name=${ref}",
  ]
}
