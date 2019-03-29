---
name: Feature request
about: Request a monitoring script for other cable modems.
title: "[FEATURE] Add support for {vendor} {model} cable modem"
labels: ''
assignees: mluis7

---

**Cable modem info**
Vendor: Arris
Model: TM702G

**Status page html source**
The status page must contain a column for octets, unerrored codewords or other value for successfully sent packets.

```html
<table width="770" cellspacing="0" cellpadding="0" border="2">
	<tbody>
		<tr>
			<td></td>
			<td>DCID</td>
			<td>Freq</td>
			<td>Power</td>
			<td>SNR</td>
			<td>Modulation</td>
			<td>Octets</td>
			<td>Correcteds</td>
			<td>Uncorrectables</td>
		</tr>
		<tr>
			<td>Downstream 1</td>
			<td>20</td>
			<td>723.00 MHz</td>
			<td>2.73 dBmV</td>
			<td>37.64 dB</td>
			<td>256QAM</td>
			<td>1081927710</td>
			<td>2039</td>
			<td>5048</td>
		</tr>
	</tbody>
</table>
```
