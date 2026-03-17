Class Solution.FromFhirObsToSIUS12 Extends Ens.DataTransformDTL [ DependsOn = (Solution.FHIRBPL.Context, EnsLib.HL7.Message) ]
{

Parameter IGNOREMISSINGSOURCE = 1;

Parameter REPORTERRORS = 1;

Parameter TREATEMPTYREPEATINGFIELDASNULL = 0;

XData DTL [ XMLNamespace = "http://www.intersystems.com/dtl" ]
{
<transform sourceClass='Solution.FHIRBPL.Context' targetClass='EnsLib.HL7.Message' targetDocType='2.5:SIU_S12' create='new' language='objectscript' >
<assign value='"^~\&amp;"' property='target.{MSH:FieldSeparator}' action='set' />
<assign value='"EPIC"' property='target.{MSH:EncodingCharacters}' action='set' />
<assign value='"EPIC"' property='target.{MSH:SendingApplication}' action='set' />
<assign value='..Strip($ZDATETIME($H,8),"*P")' property='target.{MSH:DateTimeOfMessage}' action='set' />
<assign value='"SIU"' property='target.{MSH:MessageType.MessageCode}' action='set' />
<assign value='"S12"' property='target.{MSH:MessageType.TriggerEvent}' action='set' />
<assign value='538' property='target.{MSH:MessageControlID}' action='set' />
<assign value='"D"' property='target.{MSH:ProcessingID.ProcessingID}' action='set' />
<assign value='2.5' property='target.{MSH:VersionID.VersionID}' action='set' />
<assign value='"ISO IR87"' property='target.{MSH:CharacterSet(2)}' action='set' />
<assign value='"01928374"' property='target.{SCH:PlacerAppointmentID}' action='set' />
<assign value='"57483920"' property='target.{SCH:FillerAppointmentID}' action='set' />
<assign value='"飽和酸素度が低い数値です : "_source.O2Sat' property='target.{SCH:AppointmentReason.Text}' action='set' />
<assign value='1' property='target.{SCH:AppointmentDuration}' action='set' />
<assign value='"hr"' property='target.{SCH:AppointmentDurationUnits.Identifier}' action='set' />
<assign value='1' property='target.{SCH:AppointmentTimingQuantity(1).Quantity}' action='set' />
<assign value='..Strip($ZDATETIME($H,8),"*P")' property='target.{SCH:AppointmentTimingQuantity(1).StartDateTime.Time}' action='set' />
<assign value='1173' property='target.{SCH:EnteredByPerson(1).IDNumber}' action='set' />
<assign value='"MATTHEWS"' property='target.{SCH:EnteredByPerson(1).FamilyName.Surname}' action='set' />
<assign value='"JAMES"' property='target.{SCH:EnteredByPerson(1).GivenName}' action='set' />
<assign value='"A"' property='target.{SCH:EnteredByPerson(1).SecondandFurtherGivenNamesor}' action='set' />
<assign value='"BOOKED"' property='target.{SCH:FillerStatusCode.Identifier}' action='set' />
<assign value='1' property='target.{RGSgrp(1).RGS:SetIDRGS}' action='set' />
<assign value='"A"' property='target.{RGSgrp(1).RGS:SegmentActionCode}' action='set' />
<assign value='"094"' property='target.{RGSgrp(1).RGS:ResourceGroupID.Identifier}' action='set' />
<assign value='source.PID' property='target.{PIDgrp(1).PID:PatientID.IDNumber}' action='set' />
<assign value='source.family' property='target.{PIDgrp(1).PID:PatientName(1).FamilyName}' action='set' />
<assign value='source.givenname' property='target.{PIDgrp(1).PID:PatientName(1).GivenName}' action='set' />
</transform>
}

}
