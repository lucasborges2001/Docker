.PHONY: install uninstall run status timer logs

install:
	sudo ./scripts/install.sh

uninstall:
	sudo ./scripts/uninstall.sh

run:
	sudo systemctl start docker-watch.service

status:
	systemctl status docker-watch.service --no-pager

timer:
	systemctl status docker-watch.timer --no-pager

logs:
	journalctl -u docker-watch.service -b --no-pager
