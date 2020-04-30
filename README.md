# nginx_mirror_site
### 将conf 和 html 软链接到nginx目录下面

``` shell
ln -sfn nginx_mirror_site/conf /usr/local/nginx/
ln -sfn nginx_mirror_site/html /usr/local/nginx/
```

### 或者将 conf下的文件 和 html 下面的文件 移到 nginx对应的目录中
``` shell
cp -rf nginx_mirror_site/conf/* /usr/local/nginx/conf/
cp -rf nginx_mirror_site/html/* /usr/local/nginx/html/
```