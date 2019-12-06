# Neail's blog

```bash
git clone git@github.com:Blacate/blog.git
cd blog
git clone https://github.com/theme-next/hexo-theme-next themes/next
# set next version
cd themes/next && git reset --hard 979bc699b4543e97c05624698e5e6262e10f7a84 && cd ...
cp theme_config/next/_config.yml themes/next/_config.yml
hexo new # new post
make publish # publish post & backup
```

