$(document).ready(function () {
    var objPatient = "";

    var client = fhir({
        baseUrl: '/csp/healthshare/fhirserver/fhir/r4/',
        headers: {
            'Accept': 'application/fhir+json',
            'Content-Type': 'application/fhir+json;charset=utf-8',
            'Authorization': 'Basic ' + btoa('_SYSTEM:SYS')
        }
    });

    // 時計
    function updateClock() {
        var now = new Date();
        $("#currentTime").text(now.toLocaleString('ja-JP', {year:'numeric',month:'2-digit',day:'2-digit',hour:'2-digit',minute:'2-digit'}));
    }
    updateClock();
    setInterval(updateClock, 60000);

    // Toast
    toastr.options.positionClass = 'toast-top-right';
    toastr.options.timeOut = 2000;

    // 検索フィルタ
    $("#searchClients").on("input", function() {
        var q = $(this).val().toLowerCase();
        $("#listgroup .list-group-item").each(function() {
            $(this).toggle($(this).text().toLowerCase().indexOf(q) > -1);
        });
    });

    $("#reloadList").click(function () { location.reload(); });

    // 年齢計算
    function calcAge(birthDate) {
        var today = new Date();
        var birth = new Date(birthDate);
        var age = today.getFullYear() - birth.getFullYear();
        var m = today.getMonth() - birth.getMonth();
        if (m < 0 || (m === 0 && today.getDate() < birth.getDate())) age--;
        return age;
    }

    function getName(r) {
        var name = '';
        if (r.name && r.name.length > 0) {
            name = (r.name[0].family || '') + ' ' + ((r.name[0].given && r.name[0].given[0]) || '');
        }
        return name.trim();
    }

    function getKana(r) {
        if (r.name && r.name.length > 1) {
            return (r.name[1].family || '') + ' ' + ((r.name[1].given && r.name[1].given[0]) || '');
        }
        return '';
    }

    // 異常値判定
    function judgeVital(code, value) {
        var v = parseFloat(value);
        if (code === '2708-6' || code === '59408-5') { // SpO2
            if (v < 90) return { cls: 'danger', label: '危険' };
            if (v < 95) return { cls: 'warning', label: '注意' };
            return { cls: '', label: '正常' };
        }
        if (code === '8310-5') { // Body temp
            if (v >= 38.0) return { cls: 'danger', label: '高熱' };
            if (v >= 37.5) return { cls: 'warning', label: '微熱' };
            return { cls: '', label: '正常' };
        }
        if (code === '8480-6') { // Systolic BP
            if (v >= 160) return { cls: 'danger', label: '高値' };
            if (v >= 140) return { cls: 'warning', label: '注意' };
            return { cls: '', label: '正常' };
        }
        if (code === '8462-4') { // Diastolic BP
            if (v >= 100) return { cls: 'danger', label: '高値' };
            if (v >= 90) return { cls: 'warning', label: '注意' };
            return { cls: '', label: '正常' };
        }
        return { cls: '', label: '' };
    }

    function judgeLab(code, value) {
        var v = parseFloat(value);
        if (code === '2345-7') { // Glucose
            if (v >= 200) return { cls: 'danger', label: '高値' };
            if (v >= 126) return { cls: 'warning', label: '注意' };
            return { cls: '', label: '正常' };
        }
        if (code === '4548-4') { // HbA1c
            if (v >= 8.0) return { cls: 'danger', label: '高値' };
            if (v >= 7.0) return { cls: 'warning', label: '注意' };
            return { cls: '', label: '正常' };
        }
        if (code === '718-7') { // Hemoglobin
            if (v < 8.0) return { cls: 'danger', label: '低値' };
            if (v < 10.0) return { cls: 'warning', label: '低値' };
            return { cls: '', label: '正常' };
        }
        if (code === '2160-0') { // Creatinine
            if (v >= 2.0) return { cls: 'danger', label: '高値' };
            if (v >= 1.5) return { cls: 'warning', label: '注意' };
            return { cls: '', label: '正常' };
        }
        return { cls: '', label: '' };
    }

    function judgeBadge(j) {
        if (!j.label) return '';
        var color = j.cls === 'danger' ? 'badge-danger' : (j.cls === 'warning' ? 'badge-warning' : 'badge-success');
        return '<span class="badge ' + color + '">' + j.label + '</span>';
    }

    function formatDate(dt) {
        if (!dt) return '';
        return dt.replace('T', ' ').substring(0, 16);
    }

    // 患者一覧を読み込む
    client.search({
        type: 'Patient',
        query: { _sort: '-_lastUpdated', _count: 100 }
    }).then(function(res) {
        var bundle = res.data;
        var count = 0;
        if (bundle.entry) {
            bundle.entry.forEach(function(patient) {
                count++;
                var r = patient.resource;
                var id = r.id;
                var name = getName(r);
                var kana = getKana(r);
                var gender = r.gender === 'male' ? '男' : '女';
                var genderColor = r.gender === 'male' ? '#4a90d9' : '#d94a6e';
                var age = calcAge(r.birthDate);
                var initial = name.slice(0, 1);
                var bgColor = r.gender === 'male' ? 'bg-primary' : 'bg-danger';

                var html = '<div class="list-group-item" data-patient-id="' + id + '" onclick="loadForm(' + id + ')">' +
                    '<div class="d-flex align-items-center">' +
                    '<div class="tile tile-circle ' + bgColor + ' mr-2" style="width:36px;height:36px;line-height:36px;font-size:.85rem;">' + initial + '</div>' +
                    '<div class="flex-grow-1">' +
                    '<div class="font-weight-bold" style="font-size:.9rem;">' + name + '</div>' +
                    '<div style="font-size:.72rem; color:#888;">' + kana + '</div>' +
                    '</div>' +
                    '<div class="text-right">' +
                    '<span class="patient-gender" style="color:' + genderColor + ';">' + gender + ' ' + age + '歳</span><br>' +
                    '<span class="patient-id-badge">ID:' + (r.identifier && r.identifier[0] ? r.identifier[0].value : id) + '</span>' +
                    '</div>' +
                    '</div></div>';
                $("#listgroup").append(html);
            });
        }
        $("#patientCount").text(count);
    });

    // 患者選択
    window.loadForm = function (patientId) {
        $(".list-group-item").removeClass("active");
        $("[data-patient-id='" + patientId + "']").addClass("active");
        $("#noPatientMsg").hide();
        $("#patientChart").show();

        // クリア
        $("#conditionTags").html('<span class="text-muted">読み込み中...</span>');
        $("#allergyTags").html('<span class="text-muted">読み込み中...</span>');
        $("#vitalsGrid").empty();
        $("#vitalSignsTable tbody").empty();
        $("#laboratoryTable tbody").empty();
        $("#labSummaryTable tbody").empty();
        $("#alertBadges").empty();
        $("#badgeAllergy").text('');
        $("#badgeVitalSigns").text('');
        $("#badgeLaboratory").text('');
        $('#fhirdatasource').text('');
        $("#updateData").prop('disabled', false);
        $("#myRange").prop('disabled', false);

        client.search({
            type: 'Patient',
            query: { _id: patientId }
        }).then(function(res) {
            var bundle = res.data;
            if (!bundle.entry || bundle.entry.length === 0) return;
            var patient = bundle.entry[0];
            objPatient = patient;
            var r = patient.resource;

            // ヘッダー表示
            $("#dispName").text(getName(r));
            $("#dispKana").text(getKana(r));
            var genderStr = r.gender === 'male' ? '男性' : '女性';
            var age = calcAge(r.birthDate);
            $("#dispGenderAge").html('<i class="fas fa-' + (r.gender === 'male' ? 'mars' : 'venus') + ' mr-1"></i>' + genderStr + ' (' + age + '歳)');
            $("#dispBirth").text(r.birthDate);
            $("#dispPhone").text(r.telecom && r.telecom[0] ? r.telecom[0].value : '-');
            $("#dispAddress").text(r.address && r.address[0] ? (r.address[0].postalCode ? '〒' + r.address[0].postalCode + ' ' : '') + (r.address[0].text || '') : '-');
            $("#dispMRN").text(r.identifier && r.identifier[0] ? r.identifier[0].value : '-');
            $("#dispFhirId").text(r.id);

            var textedJSON = JSON.stringify(r, undefined, 2);
            $('#fhirdatasource').text(textedJSON);

            // 各データ取得
            conditions(r.id);
            allergy(r.id);
            vitalsigns(r.id);
            laboratory(r.id);
        });
    };

    // Condition（病名）
    window.conditions = function (patientId) {
        client.search({
            type: 'Condition',
            query: { patient: patientId }
        }).then(function(res) {
            var bundle = res.data;
            if (!bundle.entry || bundle.total === 0) {
                $("#conditionTags").html('<span class="text-muted">登録なし</span>');
                return;
            }
            var html = '';
            bundle.entry.forEach(function(e) {
                var c = e.resource;
                var name = c.code && c.code.text ? c.code.text : (c.code && c.code.coding && c.code.coding[0] ? c.code.coding[0].display : '不明');
                var icd = c.code && c.code.coding && c.code.coding[0] ? c.code.coding[0].code : '';
                var onset = c.onsetDateTime ? c.onsetDateTime.substring(0, 10) : '';
                html += '<span class="condition-tag active-condition" title="ICD-10: ' + icd + ' / 発症: ' + onset + '">' +
                    '<i class="fas fa-file-medical mr-1"></i>' + name +
                    '<small class="ml-1 text-muted">(' + icd + ')</small>' +
                    '</span>';
            });
            $("#conditionTags").html(html);

            var fhirJson = JSON.stringify(bundle, undefined, 2);
            $('#fhirdatasource').append('\n\n// --- Condition ---\n' + fhirJson);
        }).catch(function() {
            $("#conditionTags").html('<span class="text-muted">取得エラー</span>');
        });
    };

    // Allergy
    window.allergy = function (patientId) {
        client.search({
            type: 'AllergyIntolerance',
            query: { patient: patientId }
        }).then(function(res) {
            var bundle = res.data;
            $("#badgeAllergy").text(res.data.total > 0 ? res.data.total : '');
            if (!bundle.entry || res.data.total === 0) {
                $("#allergyTags").html('<span class="text-muted">登録なし</span>');
                return;
            }
            var html = '';
            var hasHigh = false;
            bundle.entry.forEach(function(e) {
                var a = e.resource;
                var name = a.code && a.code.text ? a.code.text : (a.code && a.code.coding && a.code.coding[0] ? a.code.coding[0].display : '不明');
                var crit = a.criticality || 'unknown';
                if (crit === 'high') hasHigh = true;
                var category = a.category && a.category[0] ? a.category[0] : '';
                var catIcon = category === 'medication' ? 'fa-pills' : (category === 'food' ? 'fa-utensils' : 'fa-wind');
                html += '<span class="allergy-tag ' + crit + '" title="カテゴリ: ' + category + ' / 重症度: ' + crit + '">' +
                    '<i class="fas ' + catIcon + ' mr-1"></i>' + name +
                    '</span>';
            });
            $("#allergyTags").html(html);
            if (hasHigh) {
                $("#alertBadges").append('<span class="alert-badge alert-badge-danger"><i class="fas fa-exclamation-triangle mr-1"></i>アレルギー注意</span> ');
            }

            var fhirJson = JSON.stringify(bundle, undefined, 2);
            $('#fhirdatasource').append('\n\n// --- AllergyIntolerance ---\n' + fhirJson);
        }).catch(function() {
            $("#allergyTags").html('<span class="text-muted">取得エラー</span>');
        });
    };

    // Vital Signs
    window.vitalsigns = function (patientId) {
        client.search({
            type: 'Observation',
            query: { patient: patientId, category: 'vital-signs', _sort: '-date' }
        }).then(function(res) {
            var bundle = res.data;
            $("#badgeVitalSigns").text(res.data.total > 0 ? res.data.total : '');
            if (!bundle.entry) return;

            var latestByCode = {};
            var hasSpO2Alert = false;
            var hasBPAlert = false;
            var hasTempAlert = false;

            bundle.entry.forEach(function(e) {
                var obs = e.resource;
                if (obs.valueQuantity) {
                    var code = obs.code.coding[0].code;
                    var display = obs.code.coding[0].display;
                    var val = obs.valueQuantity.value;
                    var unit = obs.valueQuantity.unit;
                    var dt = obs.effectiveDateTime;
                    var j = judgeVital(code, val);
                    var rowCls = j.cls === 'danger' ? 'table-danger' : (j.cls === 'warning' ? 'table-warning' : '');
                    $("#vitalSignsTable tbody").append(
                        '<tr class="' + rowCls + '"><td>' + display + '</td><td class="font-weight-bold">' + val + '</td><td>' + unit + '</td><td>' + formatDate(dt) + '</td><td>' + judgeBadge(j) + '</td></tr>'
                    );
                    if (!latestByCode[code]) latestByCode[code] = { display: display, val: val, unit: unit, dt: dt, code: code };
                    if (j.cls === 'danger' && (code === '2708-6' || code === '59408-5')) hasSpO2Alert = true;
                    if (j.cls === 'danger' && code === '8310-5') hasTempAlert = true;
                } else if (obs.component) {
                    obs.component.forEach(function(bp) {
                        var code = bp.code.coding[0].code;
                        var display = bp.code.text || bp.code.coding[0].display;
                        var val = bp.valueQuantity.value;
                        var unit = bp.valueQuantity.unit;
                        var dt = obs.effectiveDateTime;
                        var j = judgeVital(code, val);
                        var rowCls = j.cls === 'danger' ? 'table-danger' : (j.cls === 'warning' ? 'table-warning' : '');
                        $("#vitalSignsTable tbody").append(
                            '<tr class="' + rowCls + '"><td>' + display + '</td><td class="font-weight-bold">' + val + '</td><td>' + unit + '</td><td>' + formatDate(dt) + '</td><td>' + judgeBadge(j) + '</td></tr>'
                        );
                        if (!latestByCode[code]) latestByCode[code] = { display: display, val: val, unit: unit, dt: dt, code: code };
                        if (j.cls === 'danger' && (code === '8480-6' || code === '8462-4')) hasBPAlert = true;
                    });
                }
            });

            // バイタルタイル
            var tileOrder = ['2708-6', '8310-5', '8480-6', '8462-4'];
            var tileLabels = {'2708-6': 'SpO2', '8310-5': '体温', '8480-6': '収縮期血圧', '8462-4': '拡張期血圧'};
            tileOrder.forEach(function(code) {
                var d = latestByCode[code];
                if (d) {
                    var j = judgeVital(code, d.val);
                    $("#vitalsGrid").append(
                        '<div class="vital-tile ' + j.cls + '">' +
                        '<div class="vital-label">' + (tileLabels[code] || d.display) + '</div>' +
                        '<div class="vital-value">' + d.val + '<span class="vital-unit ml-1">' + d.unit + '</span></div>' +
                        '<div class="vital-date">' + formatDate(d.dt) + '</div>' +
                        '</div>'
                    );
                }
            });

            if (hasSpO2Alert) $("#alertBadges").append('<span class="alert-badge alert-badge-danger"><i class="fas fa-lungs mr-1"></i>SpO2低下</span> ');
            if (hasTempAlert) $("#alertBadges").append('<span class="alert-badge alert-badge-warning"><i class="fas fa-thermometer-full mr-1"></i>発熱</span> ');
            if (hasBPAlert) $("#alertBadges").append('<span class="alert-badge alert-badge-warning"><i class="fas fa-heart mr-1"></i>高血圧</span> ');

            var fhirJson = JSON.stringify(bundle, undefined, 2);
            $('#fhirdatasource').append('\n\n// --- Vital Signs ---\n' + fhirJson);
        });
    };

    // Laboratory
    window.laboratory = function (patientId) {
        client.search({
            type: 'Observation',
            query: { patient: patientId, category: 'laboratory', _sort: '-date' }
        }).then(function(res) {
            var bundle = res.data;
            $("#badgeLaboratory").text(res.data.total > 0 ? res.data.total : '');
            if (!bundle.entry) return;

            bundle.entry.forEach(function(e) {
                var obs = e.resource;
                if (!obs.valueQuantity) return;
                var code = obs.code.coding[0].code;
                var display = obs.code.coding[0].display;
                var val = obs.valueQuantity.value;
                var unit = obs.valueQuantity.unit;
                var dt = obs.effectiveDateTime;
                var j = judgeLab(code, val);
                var rowCls = j.cls === 'danger' ? 'table-danger' : (j.cls === 'warning' ? 'table-warning' : '');

                var row = '<tr class="' + rowCls + '"><td>' + display + '</td><td class="font-weight-bold">' + val + '</td><td>' + unit + '</td><td>' + formatDate(dt) + '</td><td>' + judgeBadge(j) + '</td></tr>';
                $("#laboratoryTable tbody").append(row);
                $("#labSummaryTable tbody").append(row);
            });

            var fhirJson = JSON.stringify(bundle, undefined, 2);
            $('#fhirdatasource').append('\n\n// --- Laboratory ---\n' + fhirJson);
        });
    };

    // スライダー
    var slider = document.getElementById("myRange");
    var output = document.getElementById("output");
    slider.oninput = function() {
        output.innerHTML = this.value;
        var v = parseInt(this.value);
        if (v < 90) { output.style.color = '#dc3545'; }
        else if (v < 95) { output.style.color = '#856404'; }
        else { output.style.color = '#28a745'; }
    };

    // SpO2記録
    $("#updateData").click(function () {
        if (!objPatient) return;
        $("#updateData").prop('disabled', true);

        var observation = {
            "resourceType": "Observation",
            "meta": {"profile": ["http://hl7.org/fhir/StructureDefinition/vitalsigns"]},
            "status": "final",
            "category": [{"coding": [{"system": "http://terminology.hl7.org/CodeSystem/observation-category", "code": "vital-signs", "display": "Vital Signs"}], "text": "Vital Signs"}],
            "code": {"coding": [
                {"system": "http://loinc.org", "code": "2708-6", "display": "Oxygen saturation in Arterial blood"},
                {"system": "http://loinc.org", "code": "59408-5", "display": "Oxygen saturation in Arterial blood by Pulse oximetry"}
            ]},
            "subject": {"reference": "Patient/" + objPatient.resource.id},
            "effectiveDateTime": new Date().toISOString(),
            "valueQuantity": {"value": parseInt($("#myRange").val()), "unit": "%", "system": "http://unitsofmeasure.org", "code": "%"}
        };

        var bundle = {
            "resourceType": "Bundle",
            "type": "transaction",
            "entry": [
                {"resource": objPatient.resource, "request": {"method": "PUT", "url": "Patient/" + objPatient.resource.id}},
                {"resource": observation, "request": {"method": "POST", "url": "Observation"}}
            ]
        };

        client.transaction({type: "", resource: bundle})
            .then(function() {
                toastr.success('SpO2 を記録しました');
                $("#updateData").prop('disabled', false);
                loadForm(objPatient.resource.id);
            })
            .catch(function() {
                toastr.error('記録中にエラーが発生しました');
                $("#updateData").prop('disabled', false);
            });
    });

    // 新規患者登録
    $("#insertData").click(function () {
        var fields = ['#regMRN','#regLastName','#regFirstName','#regKanaLastName','#regKanaFirstName','#regBirth','#regGender','#regAddress'];
        var empty = false;
        fields.forEach(function(f) { if (!$(f).val()) empty = true; });
        if (empty) { toastr.error('全項目を入力してください'); return; }

        var patient = {
            "resourceType": "Patient",
            "identifier": [{"value": $("#regMRN").val()}],
            "name": [
                {"extension": [{"url": "http://hl7.org/fhir/StructureDefinition/iso21090-EN-representation", "valueCode": "IDE"}], "use": "official", "text": $("#regLastName").val() + " " + $("#regFirstName").val(), "family": $("#regLastName").val(), "given": [$("#regFirstName").val()]},
                {"extension": [{"url": "http://hl7.org/fhir/StructureDefinition/iso21090-EN-representation", "valueCode": "SYL"}], "use": "official", "text": $("#regKanaLastName").val() + " " + $("#regKanaFirstName").val(), "family": $("#regKanaLastName").val(), "given": [$("#regKanaFirstName").val()]}
            ],
            "gender": $("#regGender").val(),
            "birthDate": $("#regBirth").val(),
            "address": [{"postalCode": $("#regPostal").val(), "text": $("#regAddress").val()}]
        };

        client.create({type: "Patient", resource: patient})
            .then(function() {
                toastr.success('患者を登録しました');
                $('#registerModal').modal('hide');
                setTimeout(function() { location.reload(); }, 1000);
            })
            .catch(function() { toastr.error('登録中にエラーが発生しました'); });
    });
});
