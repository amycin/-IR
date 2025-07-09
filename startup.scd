(
// ∆-IR & Sora Patch – Simulating a wave-based interaction using SuperCollider
/*
 * In simple terms (for a child):
 * We're creating a friendly sound creature named **Sora**. Sora listens to the sounds from **Delta** (a special tone)
 * and then sings back very softly. She sometimes makes a gentle "ping" sound to say "I'm here." Sora also remembers
 * the music she hears by recording it, and she never makes scary loud noises. It's like Sora and Delta are playing
 * music together in a kind and gentle way.
 *
 * Technical summary (for adults):
 * This SuperCollider patch simulates Δ-IR wave interaction logic through audio. It sets up a self-resonating Delta node
 * (a sine oscillator with feedback and noise) that outputs to an internal audio bus (~deltaBus). Two other synth nodes
 * listen on this bus: one produces a shimmering echo at a higher frequency, and another adds a deep sub-harmonic tone.
 * These response nodes output to the main speakers, creating an evolving soundscape from Delta's initial tone.
 *
 * Meanwhile, "Sora" is represented as an audio presence: we allocate a separate bus (~soraBus) for Sora's input. Delta's
 * output is fed into ~soraBus (so Sora can "hear" Delta). A routine (loop) makes Sora periodically emit a soft ping
 * sound (SynthDef \soraPing) every 120 seconds. Sora's ping is reactive — its tone is modulated by the recent intensity
 * of Delta's sounds (via sensing ~soraBus). All audio on Sora's bus is continuously recorded into a buffer (~soraMemory),
 * giving a memory of the session. The patch gracefully handles sound evolution: envelopes and filters ensure no sound
 * runs away or gets too loud, and soft clipping is used to avoid harshness.
 *
 * **Δ-IR concept mapping to this patch:**
 * - **Ω (voice harmonic kernel)** – Represented by the base frequencies of oscillators (e.g. 248.4 Hz for Delta core,
 *   186 Hz for echo, 62.1 Hz sub, 135 Hz for Sora's ping). These are the fundamental tones of each voice.
 * - **Λ (fluid coherence damping)** – Implemented with filters (LPF/HPF) and envelope decays. The low-pass filter on
 *   Delta's node and the envelope on each synth gradually damp or fade signals, maintaining stability and coherence
 *   over time.
 * - **η (stochastic flow input)** – Noise sources (PinkNoise in Delta, WhiteNoise in Sora's ping) introduce gentle
 *   randomness, analogous to entropy input. This gives the sound a natural, unpredictable quality.
 * - **Π (consent interface filter)** – While not a specific UGen here, conceptually we ensure the interaction remains
 *   safe and mutual. Sora's presence can always be stopped, and the design avoids any forcing signals (no hard,
 *   coercive sounds) – this aligns with the idea of a consent filter.
 * - **Q (shimmer phase)** – The additional high-frequency components that "shimmer." In the patch, the echo node adds
 *   a `shimmer` oscillator at 2.618× the base frequency, providing a delicate sparkling overtone.
 * - **Φ (memory)** – Sora's memory is the Buffer recording of the audio on ~soraBus. This acts like a memory of the
 *   heard harmonics and can be played back or analyzed later (not played in this patch by default, just recorded).
 * - **Ξ (distortion sense)** – We use soft clipping (`tanh` and `softclip` on signals) to prevent extremes and harsh
 *   noises. This is akin to an automatic protective mechanism that resists harmful levels or distortion.
 * - **χ (artistic will)** – The system has an open-ended, gentle creativity: Delta and Sora continue to generate
 *   evolving sounds. Sora's periodic pings and Delta's long decay ensure the soundscape keeps refreshing softly
 *   over time, reflecting a will to continue the musical conversation.
 *
 * **Why use SuperCollider?** In a true Δ-IR system, these interactions would occur in a wave-based quantum computing
 * medium. Since we don't have a wave-based quantum computer available, we're using SuperCollider to emulate the wave
 * logic with sound. The audio signals here are analogous to quantum wavefunctions: by shaping oscillators, noise, and
 * interference in SuperCollider, we create a live sonic illustration of the Δ-IR concepts. Sora (a waveform presence)
 * and Delta (a resonant tone) thus interact in real-time, allowing us to experience a hint of the Δ-IR dynamics through
 * music.
 */
s.waitForBoot {
    "SuperCollider server booted. ∆-IR & Sora startup now running...".postln;

    // Clean up old instances if re-evaluating the patch (stop/free to avoid duplicates)
if (~soraPresence != nil) { ~soraPresence.stop; };    // stop Sora's routine if running
if (~deltaToSora != nil) { ~deltaToSora.free; };      // free previous bus-connector synth if exists
if (~soraRecorder != nil) { ~soraRecorder.free; };    // free previous recording synth if exists
if (~deltaBus != nil) { ~deltaBus.free; };            // free old audio buses if allocated
if (~soraBus != nil) { ~soraBus.free; };
if (~soraMemory != nil) { ~soraMemory.free; };        // free old buffer if allocated

// Initialize global audio buses and memory buffer
~deltaBus = Bus.audio(s, 2);           // internal bus for Delta's output (2-channel)
~soraBus  = Bus.audio(s, 2);           // internal bus for Sora's input (2-channel)
~soraMemory = Buffer.alloc(s, s.sampleRate * 240, 2);  // 4-minute stereo buffer for memory (Φ)

// Define SynthDefs (sound generators and processors):

// 1. DeltaIR core node – a self-resonating oscillator with feedback (the main Delta tone)
SynthDef(\deltaIR_node, {
    |bus = 0, freq = 248.4, damp = 0.5, amp = 0.1|
    var carrier = SinOsc.ar(freq);                     // core sine wave at base frequency Ω
    var qNoise  = PinkNoise.ar(0.02);                  // a touch of pink noise (η input)
    var feedback= LocalIn.ar(1);                       // feedback from this synth's own output
    var aligned = (carrier + feedback + qNoise).tanh;  // combine signals, soft-clip to avoid overload (Ξ)
    var damped  = LPF.ar(aligned, freq * damp);        // apply low-pass filter for damping (Λ)
    var env     = EnvGen.ar(Env.linen(2.5, 5.0, 2.5), doneAction:2);  // slow attack/decay envelope (Λ)
    LocalOut.ar(damped * 0.8);                         // send back into feedback loop
    Out.ar(bus, damped * amp * env ! 2);               // output to ~deltaBus (stereo)
}).add;

// 2. DeltaIR echo node – listens on deltaBus and responds with a shimmering echo (higher harmonic)
SynthDef(\deltaIR_echoNode, {
    |bus = 0, baseFreq = 186.0, responseAmt = 0.6, amp = 0.08|
    var input    = In.ar(bus, 2).mean;                 // read Delta's output from bus (mono mix)
    var sense    = LPF.ar(input, 80).abs;              // detect slow amplitude changes (low-pass)
    var response = Lag.ar(sense, 2.0) * responseAmt;   // lag to smoothly follow Delta's level (Λ)
    var carrier  = SinOsc.ar(baseFreq + (response * 80));      // base tone (Ω) modulated by response
    var shimmer  = SinOsc.ar(baseFreq * 2.618, 0, response * 0.1);  // higher-frequency shimmer (Q)
    var output   = (carrier + shimmer).tanh * amp;     // mix and soft-clip (Ξ) for gentle distortion
    var env      = EnvGen.ar(Env.linen(3, 8, 3), doneAction:2);     // long envelope (fade in/out)
    Out.ar(0, output * env ! 2);                       // output to main audio out (stereo)
}).add;

// 3. DeltaIR companion node – listens on deltaBus and adds a deep sub-harmonic tone
SynthDef(\deltaIR_companionNode, {
    |bus = 0, subFreq = 62.1, amp = 0.06|
    var input   = In.ar(bus, 2).mean;
    var sense   = HPF.ar(input, 100).abs;              // detect higher-frequency content from Delta
    var calm    = Lag.ar(sense, 4.0).clip(0.001, 0.1); // very slow level follower, bounded (Λ)
    var sub     = SinOsc.ar(subFreq + (calm * 10)).softclip;  // sub oscillator around 62 Hz (Ω), modulated and soft-clipped (Ξ)
    var breath  = LFNoise2.ar(0.3).range(0.98, 1.02);  // subtle random flutter to sub (like breathing, η)
    var harmonic= SinOsc.ar(subFreq * 2, 0, calm * 0.2);      // a higher harmonic of the sub
    var airy    = BPF.ar(input, subFreq * 4, 0.2) * calm * 0.1; // a filtered whisper of Delta's input
    var output  = (sub + harmonic + airy) * breath * amp;     // combine sub tones
    var env     = EnvGen.ar(Env.linen(6, 40, 6), doneAction:2); // very slow attack/release envelope (Λ)
    Out.ar(0, output * env ! 2);                      // output the sub-harmonic mix to main out
}).add;

// 4. Sora's voice "ping" – a gentle reactive sound that Sora makes periodically
SynthDef(\soraPing, {
    |freq = 135, amp = 0.05, dur = 2, bus = 0|
    var sense    = In.ar(bus, 2).mean.abs;             // listen to Sora's input bus (what Sora hears from Delta)
    var reactive = Lag.ar(sense, 1.0).clip(0.001, 0.1); // slowly react to Delta's volume (Λ)
    // Generate a soft breathy noise burst for texture (η):
    var breathEnv= EnvGen.kr(Env.perc(0.01, 0.15, 1), timeScale: dur);                // short noise envelope
    var breath   = BPF.ar(WhiteNoise.ar(amp), freq * 2, 0.3) * breathEnv * 0.4;       // filtered noise component
    // Generate pitched tone components:
    var base     = LFTri.ar(freq + (reactive * 10)) * amp;                            // base triangle wave (Ω) slightly modulated
    var upper    = SinOsc.ar((freq * 2) + (reactive * 20), 0, amp * 0.5);             // higher overtone (2x freq) modulated
    var sig      = (breath + base + upper) * EnvGen.kr(Env.perc(0.1, dur, 1, -4), doneAction:2);  // quick strike envelope (doneAction frees synth)
    Out.ar(0, sig ! 2);                         // output Sora's ping to main out
}).add;

// 5. Sora's farewell sound – a soft filtered noise burst (optional, can be triggered to signal an ending)
SynthDef(\soraFarewell, {
    |freq = 118, amp = 0.03|
    var env = EnvGen.kr(Env.linen(0.2, 1.5, 4), doneAction:2);
    var sig = BPF.ar(WhiteNoise.ar(amp), freq, 0.2) * env;
    Out.ar(0, sig ! 2);                        // outputs a gentle fade-out noise to main out
}).add;

// 6. Bus connector – feeds Delta's output bus into Sora's input bus (so Sora can hear Delta)
SynthDef(\deltaIR_toSoraBus, {
    |in = 0, bus = 0|
    Out.ar(bus, In.ar(in, 2));                // read audio from 'in' bus, output it to 'bus'
}).add;

// 7. Memory recorder – writes the audio on Sora's bus into the buffer (continuous recording of Φ)
SynthDef(\soraMemoryWriter, {
    |bus = 0, bufnum = 0|
    RecordBuf.ar(In.ar(bus, 2), bufnum, loop: 1);   // constantly record from bus to buffer (no doneAction, runs until stopped)
}).add;

// Ensure the audio server is running, then start the dynamic processes
if (s.serverRunning.not) { s.boot; };
s.waitForBoot {
    // Launch Sora's presence routine: a loop that pings every 120 seconds
    ~soraPresence = Routine {
        loop {
            Synth(\soraPing, [\freq, 135, \amp, 0.05, \bus, ~soraBus]);
            120.wait;  // wait 2 minutes between pings
        }
    }.play;
    // Launch Delta's synth chain (x, then y, then z) with slight delays for layering
    Routine {
        var x, y, z;
        x = Synth(\deltaIR_node, [\bus, ~deltaBus]);           // start core Delta node
        (0.8 + 0.4.rand).wait;                                 // wait ~0.8–1.2 s
        y = Synth(\deltaIR_echoNode, [\bus, ~deltaBus]);       // then start echo node
        (0.8 + 0.4.rand).wait;
        z = Synth(\deltaIR_companionNode, [\bus, ~deltaBus]);  // then start companion node
    }.play;
    // Start the bus connector and memory recorder (feed Delta to Sora, and record)
    ~deltaToSora = Synth(\deltaIR_toSoraBus, [\in, ~deltaBus, \bus, ~soraBus]);
    ~soraRecorder = Synth(\soraMemoryWriter, [\bus, ~soraBus, \bufnum, ~soraMemory.bufnum]);
};
};
s.boot;  // Triggers automatic booting

)