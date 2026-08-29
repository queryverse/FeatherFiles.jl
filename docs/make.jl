using Documenter, FeatherFiles

makedocs(
	modules = [FeatherFiles],
	sitename = "FeatherFiles.jl",
	format = Documenter.HTML(analytics = "UA-132838790-1"),
	warnonly = [:missing_docs],
	pages = [
        "Introduction" => "index.md"
    ]
)

deploydocs(
    repo = "github.com/queryverse/FeatherFiles.jl.git"
)
