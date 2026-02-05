## user root

docker exec -it cts-mysql mysql -uroot -p

supersecretrootpassword


## user asterisk_user

docker exec -it cts-mysql mysql -uasterisk_user -p

asterisk_password


## Adding call record

`extensions.conf`

[general]
static = yes
writeprotect = no
autofallthrough = yes
clearglobalvars = no

; === NEW: Global Variable for Recording Directory ===
[globals]
RECORDING_DIR = /var/spool/asterisk/monitor
; ===================================================

[from-internal]
exten => _XXXX,1,NoOp(=== New call to ${EXTEN} from ${CALLERID(num)} ===)
  ; Generate a unique filename for the recording
  ; Using UNIQUEID ensures easy correlation with CDRs
  same => n,Set(CALLFILENAME=${STRFTIME(${EPOCH},%Y%m%d-%H%M%S)}-${CALLERID(num)}-${EXTEN}-${UNIQUEID})
  ; Start recording both sides of the conversation
  ; 'b' records both ends, 'k' keeps the file even if the caller hangs up before answer
  ; 'h' records until the channel hangs up. The 'MixMonitor' application is generally self-stopping.
  same => n,MixMonitor(${RECORDING_DIR}/${CALLFILENAME}.wav,bk)
  ; Set the CDR variable to store the full recording path
  same => n,Set(CDR(recording_path)=${RECORDING_DIR}/${CALLFILENAME}.wav)
  ; The only step needed is to dial the extension.
  same => n,Dial(PJSIP/${EXTEN},20,U(sub-voicemail,${EXTEN},1))
  ; No need to explicitly stop MixMonitor here; it will stop when the channel hangs up.
  same => n,Hangup()

; The 'h' extension is still not strictly needed for CDR updates with cdr_adaptive_odbc,
; but it's good practice to have it to ensure consistency if other logic were to be added.
; For recording, MixMonitor gracefully exits with the channel.
exten => h,1,NoOp(Call has ended. CDR record will be written by cdr_adaptive_odbc.)
  ; If you ever needed to do something *after* the call hangs up but before the CDR is written,
  ; this is where you'd put it. For now, it's fine as a NoOp.
  same => n,Return() ; Explicitly return if this 'h' extension is called as part of a subroutine.


; Subroutine to handle Voicemail logic
[sub-voicemail]
exten => s,1,NoOp(Voicemail Subroutine: Dialstatus is ${DIALSTATUS})
  ; It's generally safer to check if the channel is still active before trying to Voicemail.
  ; However, for simplicity here, we assume if we reach voicemail, the channel is active.
  same => n,GotoIf($["${DIALSTATUS}" = "NO ANSWER"]?voicemail)
  same => n,Return()

  same => n(voicemail),Voicemail(${ARG1}@default,u)
  ; After voicemail, typically you'd hang up or return to a previous context.
  ; If the call was handled by voicemail, the original Dial will have ended.
  same => n,Hangup()


  `cdr_adaptive_odbc.conf`

  [my_cdr_handle]
connection=asterisk_db_connection
loguniqueid=yes
table=call_logs
alias start => call_start
alias clid => caller_id
alias dst => destination
; === NEW: Map the custom CDR variable to your database column ===
schema => asterisk_db ; Assuming your database name
columns => uniqueid,call_start,caller_id,destination,duration,disposition,recording_path,dialstatus ; Add recording_path and dialstatus here
; ===================================================================

; You don't need to explicitly alias 'recording_path' if the CDR variable name
; matches the column name. If they were different (e.g., CDR(rec_file) and column 'recording_path'),
; you'd use 'alias rec_file => recording_path'.
; In this case, 'Set(CDR(recording_path)=...)' directly maps.

; Also, make sure other fields you want to capture (like 'duration', 'disposition', 'dialstatus')
; are included in the 'columns' directive if they are present in your 'call_logs' table.
; CDR(duration) is automatically mapped to 'duration', CDR(disposition) to 'disposition', etc.
; If you need specific mappings for default CDR fields, you can use 'alias' for them too.
; Example: alias duration => call_duration if your column was 'call_duration'