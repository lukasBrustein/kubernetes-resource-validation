# Access Capacity Values

echo "Validierungsfunktion gestartet..."

set -e
KUBECTL='kubectl'
NODES=$($KUBECTL get nodes --no-headers -o custom-columns=NAME:.metadata.name)

function monitoring(){
        # Read package insert
        echo "Bitte geben Sie die benÃ¶tigte CPU Leistung in milli-units an (e.g. 500m = 0.5 requests/second):"
        read needed_cpu_capacity

        echo "Bitte geben Sie die benÃ¶tigte HauptspeicherkapazitÃ¤t ein (in Ki):"
        read needed_memory_capacity

        echo

        for n in $NODES; do
                echo "ÃœberprÃ¼fung von:" $n

                ## Check for CPU  workload
                # Check cores
                local cpu_cores=$($KUBECTL describe node $n | grep -i "Capacity:" -A 1 | grep -Eo '[0-9]+$')
                echo "Cores:" $cpu_cores

                # Multiply to get CPU power in milli-units
                local cpu_power=$(($cpu_cores * 1000))
                echo "CPU power (in m):" $cpu_power

                # Read current CPU usage
                local cpu_usage=$($KUBECTL describe node $n | grep -A3 -E "\\s\sRequests" | tail -n2 | awk 'NR==1 {print $2}')
                local cpu_usage_m=$(echo ${cpu_usage} | grep -o '[0-9]*')
                echo "CPU usage:" $cpu_usage

                # Calculate remaining CPU power
                if  [[  "$(echo -n ${cpu_usage} | tail -c1)" == "m" ]]
                then
                        local remaining_cpu=$(($cpu_power - $cpu_usage_m - $needed_cpu_capacity))
                else
                        local remaining_cpu=$(($cpu_power - $cpu_usage - $needed_cpu_capacity))
                fi
                echo "Verbleibende CPU Power (in m):" $remaining_cpu

                # Calculate if remaining CPU power is > 40%
                if [ $(echo "if ($remaining_cpu > $(bc<<<$cpu_power*0.4)) 1 else 0" | bc) -eq 1 ]
                then
                        local cpu=true
                else
                        local cpu=false
                fi
                echo "CPU-Auslastung wÃ¤hrend Deployment maximal 60%? Antwort:" $cpu

                ## Check for Memory workload
                # Check memory
                local memory=$($KUBECTL describe node $n | grep -i "Capacity:" -A5 | tail -n1 | awk '{print $2}')
                echo "Memory:" $memory
                local memory_num=$(echo $memory | grep -o '[0-9]*')
                # Read current memory usage
                local memory_usage=$($KUBECTL describe node $n | grep -A3 -E "\\s\sRequests" | tail -n2 | awk 'NR==2 {print $2}')
                echo "Memory usage:" $memory_usage
                local memory_usage_num=$(echo $memory_usage | grep -o '[0-9]*')

                # Calculate remaining memory
                if [[ "$(echo -n $memory_usage | tail -c2)" == 'Gi' ]]
                then
                        local remaining_memory=$(($memory_num - ($memory_usage_num * 1000000) - $needed_memory_capacity))
                elif [[ "$(echo -n $memory_usage | tail -c2)" == 'Mi' ]]
                then
                        local remaining_memory=$(($memory_num - ($memory_usage_num * 1000) - $needed_memory_capacity))
                elif [[ "$(echo -n $memory_usage | tail -c2)" == 'Ki' ]]
                then
                        local remaining_memory=$(($memory_num - $memory_usage_num - $needed_memory_capacity))
                else
                        local remaining_memory=$(($memory_num - $memory_usage_num - $needed_memory_capacity))
                fi
                echo "Verbleibender Memory (in Ki):" $remaining_memory

                # Calculate if remaining memory is > 40%
                if [ $(echo "if ($remaining_memory > $(bc<<<$memory_num*0.4)) 1 else 0" | bc) -eq 1 ]
                then
                        local mem=true
                else
                        local mem=false
                fi
                echo "Hauptspeicherauslastung wÃ¤hrend Deployment maximal 60%? Antwort:" $mem

                # Decision
                if $cpu && $mem
                then
                        echo "Deployment startet ..."
                else
                        echo "Deployment kann nicht durchgefÃ¼hrt werden!"
                fi

                echo
        done
}
        monitoring $NODES

