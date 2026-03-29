from flask import Flask, jsonify
import psutil, os, threading, time, math

app = Flask(__name__)

_mem_holder = None


@app.route('/')
def home():
    return jsonify({
        'service': 'autoscale-demo',
        'status': 'running',
        'host': os.uname().nodename,
        'cpu_percent': psutil.cpu_percent(),
        'memory_percent': psutil.virtual_memory().percent
    })


@app.route('/health')
def health():
    return jsonify({'status': 'healthy'}), 200


@app.route('/stress/cpu/<int:seconds>')
def stress_cpu(seconds):
    """Generate CPU load for N seconds to trigger scaling"""
    def burn():
        end = time.time() + seconds
        while time.time() < end:
            math.sqrt(123456.789) * math.pi

    threads = [threading.Thread(target=burn)
               for _ in range(os.cpu_count())]
    for t in threads:
        t.start()

    return jsonify({'msg': f'CPU stress for {seconds}s started'})


@app.route('/stress/memory/<int:mb>')
def stress_memory(mb):
    """Allocate N MB of memory to trigger scaling"""
    global _mem_holder
    _mem_holder = bytearray(mb * 1024 * 1024)
    return jsonify({'msg': f'{mb}MB allocated'})


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
