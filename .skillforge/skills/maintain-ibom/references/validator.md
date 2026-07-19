# Ledger validator — runnable rules

The **executable** half of `ledger-validation.md`. POSIX `awk`, so there is nothing to install — it runs
on a bare laptop, in CI, and on a foreign checkout with no network.

**Semantic rules only.** The structural layer (shape, enums, patterns, required fields) is already
executable as `catalog-info.schema.json`. Do **not** re-express it here in `grep` — the two would drift.
This file asserts what a JSON Schema cannot: cross-field arithmetic, cross-entity consistency, and
existential checks ("this slot must be named by something else in the file"). **One lexical rule lives
here too — H11 (no stray comments) — for the same reason: comments are stripped before a JSON Schema
parses the document, so the raw-text `awk` pass is the only place a comment is observable.**

## How to run

**Extract and run** — no agent required. This is also the CI job:

```sh
# run.sh <validator.md> <catalog-info.yaml>   → exit 0 clean, 1 on any violation
MD=$1; Y=$2; d=$(mktemp -d); rc=0
awk -v D="$d" '/^```awk/{c++;f=1;next} /^```$/{f=0;next} f{print > (D "/r" c ".awk")}' "$MD"
for r in "$d"/r*.awk; do awk -f "$r" "$Y" || rc=1; done
rm -rf "$d"; exit $rc
```

**As an agent:** run each `awk` block below **verbatim** against the emitted `catalog-info.yaml`. Run
them; do not interpret them. Each prints its own violations and exits non-zero. **Never redirect
`stderr`** — a rule with a syntax error prints nothing and looks clean.

---

## C9c — no silent vendoring

Every `interface.vendored/<member>` slot must be named by at least one `absorbed=` (candidate lane) or
`interface.absorbed/source` (entity). A vendored member declaring **no** surface is a silent absorption.

```awk
/^[ \t]*#/ { next }                                   # comments are not facts
function flush(  k){
  for(k in slot) if(!(k in decl)){
    printf "  x C9c %s: vendored '%s' declares no surface (silent absorption)\n", e, k; bad++ }
  delete slot; delete decl; e="?"
}
/^---[ \t]*$/                                              { flush(); next }
/^  name:/                                                 { e=$0; sub(/^  name:[ \t]*/,"",e) }
match($0,/^[ \t]*interface\.vendored\/[A-Za-z0-9._-]+/)    { k=substr($0,RSTART,RLENGTH); sub(/.*\//,"",k); slot[k]=1 }
match($0,/absorbed=[^@;"]+@/)                              { k=substr($0,RSTART,RLENGTH); sub(/^absorbed=/,"",k); sub(/@$/,"",k); sub(/.*\//,"",k); decl[k]=1 }
match($0,/interface\.absorbed\/source:[ \t]*[^@]+@/)       { k=substr($0,RSTART,RLENGTH); sub(/.*:[ \t]*/,"",k); sub(/@$/,"",k); sub(/.*\//,"",k); decl[k]=1 }
END { flush(); exit(bad>0) }
```

## C8 — federation accounting

`interface.federation` = `M/N` counts slots **filled** (vendored + referenced). `N` = member count;
`N − M` = degraded holes; `R ≤ M`; `S ≤ M − R`; `mode` must agree with the counts.
`interface.federation` is **not** a federation claim — only `…/referenced` is.

```awk
/^[ \t]*#/ { next }
function cnt(s,  a){ return s=="" ? 0 : split(s,a,",") }
function flush(  M,N,R,S,H,want,mem){
  if(fed!=""){
    split(fed,f,"/"); M=f[1]+0; N=f[2]+0
    split(ref,g,"/"); R=g[1]+0
    split(stl,h,"/"); S=h[1]+0
    H=cnt(deg); mem=cnt(mm)
    if(mem!=N)          {printf "  x C8 %s: denominator %d != %d members\n",e,N,mem; bad++}
    if(N-M!=H)          {printf "  x C8 %s: N-M=%d but %d degraded holes\n",e,N-M,H; bad++}
    if(M!=slots+R)      {printf "  x C8 %s: filled=%d != vendored(%d)+referenced(%d)\n",e,M,slots,R; bad++}
    if(R>M || S>M-R)    {printf "  x C8 %s: R=%d S=%d violate R<=M and S<=M-R (M=%d)\n",e,R,S,M; bad++}
    want=(R==M&&M>0)?"referenced":((R==0&&M>0)?"vendored":"mixed")
    if(md!=""&&md!=want){printf "  x C8 %s: mode=%s but counts imply %s\n",e,md,want; bad++}
  }
  fed="";ref="";stl="";deg="";mm="";md="";slots=0;e="?"
}
/^---[ \t]*$/                                { flush(); next }
/^  name:/                                   { e=$0; sub(/^  name:[ \t]*/,"",e) }
/^[ \t]*interface\.federation:/              { fed=$0; sub(/.*federation:[ \t]*/,"",fed); gsub(/["' ]/,"",fed) }
/^[ \t]*interface\.federation\/referenced:/  { ref=$0; sub(/.*referenced:[ \t]*/,"",ref); gsub(/["' ]/,"",ref) }
/^[ \t]*interface\.federation\/stale:/       { stl=$0; sub(/.*stale:[ \t]*/,"",stl);      gsub(/["' ]/,"",stl) }
/^[ \t]*interface\.federation\/degraded:/    { deg=$0; sub(/.*degraded:[ \t]*/,"",deg);   gsub(/["']/,"",deg) }
/^[ \t]*interface\.federation\/mode:/        { md=$0;  sub(/.*mode:[ \t]*/,"",md);        gsub(/["' ]/,"",md) }
/^[ \t]*interface\.members:/                 { mm=$0;  sub(/.*members:[ \t]*/,"",mm);     gsub(/["']/,"",mm) }
/^[ \t]*interface\.vendored\//               { slots++ }
END { flush(); exit(bad>0) }
```

## R2 — confidence never reads surer than its least-sure fact

An entity's `interface.discovery/confidence` must never **exceed** the minimum among its committed facts.

> Asserted **one-directionally on purpose.** The spec says *equals* the min — but a degraded parent
> legitimately floors itself **below** the min (an unread member contributes no facts). Asserting
> equality would fire on an honest degrade. Do not "fix" this to `!=`.

```awk
/^[ \t]*#/ { next }
function rk(c){ return c=="high"?2:(c=="medium"?1:0) }
function flush(){
  if(e!="?" && ec!="" && nf>0 && rk(ec)>mn) {
    printf "  x R2 %s: entity confidence=%s but least-sure fact=%s\n", e, ec, mnc; bad++ }
  e="?"; ec=""; nf=0; mn=99; mnc=""
}
BEGIN { mn=99; e="?" }
/^---[ \t]*$/                                    { flush(); next }
/^  name:/                                       { e=$0; sub(/^  name:[ \t]*/,"",e) }
/^[ \t]*interface\.discovery\/confidence:/       { ec=$0; sub(/.*confidence:[ \t]*/,"",ec); gsub(/["' ]/,"",ec) }
match($0,/confidence=(high|medium|low)/)         { c=substr($0,RSTART+11,RLENGTH-11); nf++; if(rk(c)<mn){mn=rk(c); mnc=c} }
END { flush(); exit(bad>0) }
```

## H11 — no comments except the self-describing header

The committed ledger is **facts only**. A `#` comment is a *fact without provenance* — it never passed
the ladder or a review state — so narrative belongs in the discovery report, a caveat in the questions
sidecar, a fact in a field. The **only** allowed comments are the self-describing header at the top of
the file: the `# yaml-language-server:` modeline and the `maintain-ibom` / `understand-ibom` marker
lines, in the leading block **before the first content line**. Any other `#` line — a narrative header
block, an inline section note — fails.

> **Full-line comments only** (`^[ \t]*#`); an inline trailing `#` is a deliberate gap — a `#` inside a
> quoted value is not a comment.

```awk
BEGIN { hz=1 }                                    # header zone: before the first content line
/^[ \t]*$/ { next }                               # blank lines are transparent
/^[ \t]*#/ {                                      # a full-line comment
  if (hz && ( $0 ~ /^#[ \t]*yaml-language-server:/ \
           || $0 ~ /^#[ \t]*maintain-ibom[ \t]+reconciliation[ \t]+ledger/ \
           || $0 ~ /^#[ \t]*the[ \t]+understand-ibom[ \t]+skill/ )) next
  s=$0; if(length(s)>72) s=substr(s,1,72) "..."
  printf "  x H11 line %d: non-header comment (fact->field, narrative->discovery report, caveat->sidecar): %s\n", NR, s
  bad++; next
}
{ hz=0 }                                          # first non-blank non-comment line closes the header zone
END { exit(bad>0) }
```

---

## Coverage caveat — a green run is not a clean ledger

These rules are a **subset** of the rules specified in `ledger-validation.md`. A green
run means **these** rules passed — **not** that the ledger is fully valid. Report what the rules
printed; never upgrade it to "the ledger validates."
