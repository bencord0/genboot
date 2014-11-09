FROM bencord0/gentoo-systemd

ADD README /root/README
ADD dockerfiles/package.keywords/sys-libs /etc/portage/package.keywords/sys-libs
ADD dockerfiles/package.use/dev-util /etc/portage/package.use/dev-util
ADD dockerfiles/package.use/sys-apps /etc/portage/package.use/sys-apps
ADD dockerfiles/make.conf /etc/portage/make.conf

CMD ["/bin/bash", "/root/README"]
