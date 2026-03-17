///
Class Solution.FHIRBPL Extends Ens.BusinessProcessBPL
{

Storage Default
{
<Type>%Storage.Persistent</Type>
}

/// BPL Definition
XData BPL [ XMLNamespace = "http://www.intersystems.com/bpl" ]
{
<process language='objectscript' request='HS.FHIRServer.Interop.Request' response='HS.FHIRServer.Interop.Response' height='2000' width='2000' >
<context>
<property name='O2Sat' type='%Integer' instantiate='0' />
<property name='Schedule' type='EnsLib.HL7.Message' instantiate='0' />
<property name='family' type='%String' instantiate='0' >
<parameters>
<parameter name='MAXLEN'  value='50' />
</parameters>
</property>
<property name='givenname' type='%String' instantiate='0' >
<parameters>
<parameter name='MAXLEN'  value='50' />
</parameters>
</property>
<property name='PID' type='%String' instantiate='0' >
<parameters>
<parameter name='MAXLEN'  value='50' />
</parameters>
</property>
</context>
<sequence xend='200' yend='900' >
<call name='Call Operation' target='HS.FHIRServer.Interop.Operation' async='0' xpos='200' ypos='250' >
<annotation><![CDATA[Pass FHIR requests onto FHIR server for CRUD operations]]></annotation>
<request type='HS.FHIRServer.Interop.Request' >
<assign property="callrequest" value="request" action="set" />
</request>
<response type='HS.FHIRServer.Interop.Response' >
<assign property="response" value="callresponse" action="set" />
</response>
</call>
<code name='Get O2 Data' xpos='200' ypos='350' >
<annotation><![CDATA[Unpack FHIR payload and expose the oxygen saturation in the context variable O2Sat]]></annotation>
<![CDATA[
  // POST時のリソースに何が含まれているか確認のためストリームからJSONに変換
  if (request.Request.RequestMethod="POST") {
     set quickStream = ##class(HS.SDA3.QuickStream).%OpenId(request.QuickStreamId)
     set json=##class(%DynamicObject).%FromJSON(quickStream)
  }

  // Observation（オキシメーター値）はBundleで渡される
  // Patient単一更新以外を判定するには RequestPath=""の時として判断
  if (request.Request.RequestMethod="POST") && (request.Request.RequestPath=""){

    set context.O2Sat = json.entry.%Get(1).resource.valueQuantity.value
    set context.family = json.entry.%Get(0).resource.name.%Get(0).family
    set context.givenname=json.entry.%Get(0).resource.name.%Get(0).given.%Get(0)
    set context.PID = json.entry.%Get(0).resource.identifier.%Get(0).value
    $$$TRACE("valueQuantity の値: "_context.O2Sat_"|"_context.family_context.givenname)
 }]]>
</code>
<if name='Check O2 Levels' condition='context.O2Sat &amp;&amp; (context.O2Sat &lt; 90) ' xpos='200' ypos='450' xend='200' yend='800' >
<true>
<transform name='Trasform to send' class='Solution.FromFhirObsToSIUS12' source='context' target='context.Schedule' xpos='335' ypos='600' />
<call name='To Scheduling Service' target='To_Scheduling' async='1' xpos='335' ypos='700' >
<request type='EnsLib.HL7.Message' >
<assign property="callrequest" value="context.Schedule" action="set" />
</request>
</call>
</true>
</if>
</sequence>
</process>
}

}
