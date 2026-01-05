#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# LIST USERS v2.0 — Lista usuários e verifica WhatsApp Business por usuário
# =============================================================================

RAW_USERS=$(su -c "pm list users")

# Extrai apenas as linhas UserInfo
USER_LINES=$(echo "$RAW_USERS" | grep "UserInfo")

TOTAL=$(echo "$USER_LINES" | wc -l | tr -d ' ')

echo "["

echo "  {"
echo "    \"success\": true,"
echo "    \"total\": $TOTAL,"
echo "    \"users\": ["

INDEX=0

echo "$USER_LINES" | while read -r line; do
  INDEX=$((INDEX + 1))

  # Parse do UserInfo{ID:NAME:FLAGS}
  ID=$(echo "$line" | sed -n 's/.*UserInfo{\([0-9]\+\):.*/\1/p')
  NAME=$(echo "$line" | sed -n 's/.*UserInfo{[0-9]\+:\([^:]*\):.*/\1/p')
  FLAGS=$(echo "$line" | sed -n 's/.*UserInfo{[0-9]\+:[^:]*:\([^}]*\)}.*/\1/p')

  if echo "$line" | grep -q "running"; then
    RUNNING=true
  else
    RUNNING=false
  fi

  # Verifica WhatsApp Business
  if su -c "pm list packages --user $ID | grep -q com.whatsapp.w4b"; then
    W4B=true
  else
    W4B=false
  fi

  echo "      {"
  echo "        \"id\": $ID,"
  echo "        \"name\": \"$NAME\","
  echo "        \"flags\": \"$FLAGS\","
  echo "        \"running\": $RUNNING,"
  echo "        \"whatsapp-business\": $W4B"
  echo -n "      }"

  # Vírgula entre usuários
  if [ "$INDEX" -lt "$TOTAL" ]; then
    echo ","
  else
    echo
  fi

done

echo "    ],"
echo "    \"raw\": \"$(echo "$RAW_USERS" | sed ':a;N;$!ba;s/\n/\\n/g')\""
echo "  }"
echo "]"
