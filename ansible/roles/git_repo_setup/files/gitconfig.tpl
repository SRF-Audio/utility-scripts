# [user]
#    name = Default Name
#    email = default@example.com

[includeIf "gitdir:~/GitHub/"]
    path = ~/.gitconfig-github

[includeIf "gitdir:~/GitLab/"]
    path = ~/.gitconfig-gitlab
