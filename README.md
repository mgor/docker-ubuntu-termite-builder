# docker-ubuntu-termite-builder

Build latest termite as a debian (ubuntu) package.

```bash
make
```

Packages are available in `packages/`.

The two important ones:
```bash
sudo dpkg -i libvte-2.91-0_*.deb termite_*.deb
```
