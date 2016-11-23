# stow
storescp>stow

This executable is a complement to dcmtk storescp which forwards with DICOMweb stow to dcm4chee-arc-light the files received by DICOM storescp.

dcmtk storescp launchd should be set somehow like that:

<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>Label</key>
	<string>org.dcmtk.storescp.plist</string>
	<key>EnvironmentVariables</key>
	<dict>
		<key>DCMDICTPATH</key>
		<string>/Users/Shared/storescp/dicom.dic</string>
	</dict>
	<key>StandardOutPath</key>
	<string>/Library/Logs/storescp.log</string>
	<key>StandardErrorPath</key>
	<string>/Library/Logs/storescp.log</string>
	<key>ProgramArguments</key>
	<array>
		<string>/Users/Shared/storescp/storescp</string>
		<string>-pm</string>
		<string>+xe</string>
		<string>-aet</string>
		<string>wfmFIR</string>
		<string>-pdu</string>
		<string>131072</string>
		<string>-dhl</string>
		<string>-up</string>
		<string>-od</string>
		<string>/Volumes/TM/wfmFIR/DICOM</string>
		<string>-su</string>
		<string></string>
		<string>-uf</string>
		<string>-xcs</string>
		<string>/Users/Shared/stow/stow #a #r #p http://192.168.0.7:8080/dcm4chee-arc/aets/%@/rs/studies</string>
		<string>-tos</string>
		<string>10</string>
		<string>104</string>
	</array>
	<key>KeepAlive</key>
	<true/>
</dict>
</plist>

The -su parameter indicates that the study folder is named after the StudyInstanceUID
The -xcs parameter triggers stow with the following parameters:
1. calling aet
2. calling ip
3. path to the study folder
4. url of dcm4chee-arc-light stow (%@ shall be replaced by calling aet)

Operation logs are visible from console.app and also spotlight searchable.
Study folders received in /DICOM are moved to /STOWED when the operation was successfull or to /ERROR if there was a problem.
