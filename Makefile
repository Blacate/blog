publish:
	hexo d -g
	git add .
	git commit -m "backup at `date -R`"
	git push
