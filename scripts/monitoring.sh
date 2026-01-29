#!/bin/bash
echo "Starting port-forwards for monitoring..."
kubectl port-forward -n cloudsound svc/cloudsound-grafana 3000:80 &
kubectl port-forward -n cloudsound svc/cloudsound-prometheus-server 9090:80 &
kubectl port-forward -n cloudsound svc/loki-gateway 3100:80 &
echo ""
echo "✅ Grafana: http://localhost:3000 (admin / cloudsound-admin)"
echo "✅ Prometheus: http://localhost:9090"
echo "✅ Loki: http://localhost:3100"
echo ""
echo "Press Ctrl+C to stop all port-forwards"