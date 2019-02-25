using Documenter, FeatherFiles

makedocs(
	modules = [FeatherFiles],
	sitename = "FeatherFiles.jl",
	analytics="UA-132838790-1",
	pages = [
        "Introduction" => "index.md"
    ]
)

deploydocs(
    repo = "github.com/queryverse/FeatherFiles.jl.git"
)
