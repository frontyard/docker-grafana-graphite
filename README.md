StatsD 0.8.0 + Graphite 1.1.3 + Grafana 5.1.0
---------------------------------------------

This image contains a sensible default configuration of StatsD, Graphite and Grafana. It is based on [Ken DeLong's repository on the Docker Index](https://index.docker.io/u/kenwdelong/) and published under [Maria Łysik's repository](https://hub.docker.com/u/marial/).

The container exposes the following ports:
- `80`: the Grafana web interface.
- `2003`: the Carbon port.
- `8125`: the StatsD port.
- `8126`: the StatsD administrative port.
If you already have services running on your host that are using any of these ports, you may wish to map the container
ports to whatever you want by changing left side number in the `-p` parameters. Find more details about mapping ports
in the [Docker documentation](http://docs.docker.io/use/port_redirection/#port-redirection).

There are three ways for using this image:

### Building the image yourself ###
The Dockerfile and supporting configuration files are available in [Github repository](https://github.com/frontyard/docker-grafana-graphite).
This comes specially handy if you want to change any of the StatsD, Graphite or Grafana settings, or simply if you want to know how the image was built.

### Using the Docker Index ###
```bash
docker run -d -p 10080:80 -p 8125:8125/udp -p 8126:8126 -p 2003:2003 --name grafana frontyard/grafana-graphite-statsd
```

### Building local image
```bash
docker build -t grafana .
docker run -d -p 10080:80 -p 8125:8125/udp -p 8126:8126 -p 2003:2003 --name grafana grafana
```
Then point your browser to http://localhost:10080
And log in with admin/admin


#### External Volumes ####
External volumes can be used to customize graphite configuration and store data out of the container.
- Graphite configuration: `/opt/graphite/conf`
- Graphite data: `/opt/graphite/storage/whisper`
- Supervisord log: `/var/log/supervisor`

### Using the Dashboard ###
Once your container is running all you need to do is:
- open your browser pointing to the host/port you just published
- login with the default username (admin) and password (admin)
- configure a new datasource to point at the Graphite metric data (URL - http://localhost:8000) and replace the default Grafana test datasource for your graphs
- open your browser pointing to the host/port you just published and play with the dashboard at your wish...