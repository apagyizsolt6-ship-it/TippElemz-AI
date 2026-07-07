import React, { useState } from 'react';
import { StyleSheet, Text, View, TouchableOpacity, ScrollView, Alert, SafeAreaView } from 'react-native';
import { StatusBar } from 'expo-status-bar';

export default function App() {
  const [activeTab, setActiveTab] = useState('ai');
  const [matches, setMatches] = useState([]);
  const [savedTips, setSavedTips] = useState([]);

  // Meccsek generálása natív listába
  const loadMatches = () => {
    const liveMatches = [
      { id: '1', home: "Real Madrid", away: "Barcelona", league: "La Liga" },
      { id: '2', home: "Man. City", away: "Liverpool", league: "Premier League" },
      { id: '3', home: "Bayern München", away: "Dortmund", league: "Bundesliga" },
      { id: '4', home: "Inter", away: "AC Milan", league: "Serie A" }
    ];
    setMatches(liveMatches);
  };

  // Natív felugró ablakos AI elemzés (Alert.alert)
  const analyzeMatch = (home, away) => {
    const predictions = ["1X", "X2", "2.5 gól felett", "Mindkét csapat lő gólt"];
    const randomPick = predictions[Math.floor(Math.random() * predictions.length)];

    Alert.alert(
      "🤖 AI Tippelemzés",
      `Meccs: ${home} - ${away}\n\nAjánlott natív tipp: ${randomPick}`,
      [
        { text: "Mégse", style: "cancel" },
        { 
          text: "Mentés az appba", 
          onPress: () => {
            setSavedTips([...savedTips, { id: Date.now().toString(), match: `${home} - ${away}`, pick: randomPick }]);
          } 
        }
      ]
    );
  };

  return (
    <SafeAreaView style={styles.container}>
      <StatusBar style="light" />
      
      {/* Fejléc */}
      <View style={styles.header}>
        <Text style={styles.headerTitle}>🔮 AI TIPPELEMZŐ NATÍV</Text>
      </View>

      {/* Tartalom terület */}
      <ScrollView style={styles.content}>
        {activeTab === 'ai' && (
          <View style={styles.card}>
            <Text style={styles.cardTitle}>Élő / Hamarosan kezdődő meccsek</Text>
            <TouchableOpacity style={styles.button} onPress={loadMatches}>
              <Text style={styles.buttonText}>Meccsek Lekérése</Text>
            </TouchableOpacity>

            {matches.map(m => (
              <TouchableOpacity key={m.id} style={styles.matchCard} onPress={() => analyzeMatch(m.home, m.away)}>
                <Text style={styles.leagueText}>🏆 {m.league}</Text>
                <View style={styles.matchRow}>
                  <Text style={styles.teamText}>{m.home}</Text>
                  <View style={styles.vsBox}><Text style={styles.vsText}>VS</Text></View>
                  <Text style={[styles.teamText, { textAlign: 'left' }]}>{m.away}</Text>
                </View>
              </TouchableOpacity>
            ))}
          </View>
        )}

        {activeTab === 'tips' && (
          <View style={styles.card}>
            <Text style={styles.cardTitle}>Mentett tippjeid az eszközön</Text>
            {savedTips.length === 0 ? (
              <Text style={styles.emptyText}>Nincs még elmentett tipped.</Text>
            ) : (
              savedTips.map(t => (
                <View key={t.id} style={styles.tipRow}>
                  <View>
                    <Text style={{ color: '#fff', fontWeight: 'bold' }}>{t.match}</Text>
                    <Text style={{ color: '#10b981', marginTop: 4 }}>🔮 {t.pick}</Text>
                  </View>
                </View>
              ))
            )}
          </View>
        )}
      </ScrollView>

      {/* Natív Alsó Navigációs Sáv */}
      <View style={styles.navBar}>
        <TouchableOpacity style={styles.navItem} onPress={() => setActiveTab('ai')}>
          <Text style={[styles.navText, activeTab === 'ai' && styles.navTextActive]}>⚽ Elemző</Text>
        </TouchableOpacity>
        <TouchableOpacity style={styles.navItem} onPress={() => setActiveTab('tips')}>
          <Text style={[styles.navText, activeTab === 'tips' && styles.navTextActive]}>📋 Tippek ({savedTips.length})</Text>
        </TouchableOpacity>
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, backgroundColor: '#0b0f19' },
  header: { backgroundColor: '#151f32', padding: 20, alignItems: 'center', borderBottomWidth: 1, borderColor: '#1e293b' },
  headerTitle: { color: '#fff', fontSize: 18, fontWeight: 'bold' },
  content: { flex: 1, padding: 15 },
  card: { backgroundColor: '#151f32', borderRadius: 16, padding: 20, marginBottom: 15 },
  cardTitle: { color: '#fff', fontSize: 16, fontWeight: 'bold', marginBottom: 15 },
  button: { backgroundColor: '#10b981', padding: 15, borderRadius: 12, alignItems: 'center' },
  buttonText: { color: '#fff', fontWeight: 'bold', fontSize: 16 },
  matchCard: { backgroundColor: '#1e293b', padding: 15, borderRadius: 12, marginTop: 12, borderWidth: 1, borderColor: '#334155' },
  leagueText: { color: '#64748b', fontSize: 12, textAlign: 'center', marginBottom: 5, fontWeight: '600' },
  matchRow: { flexDirection: 'row', justifyContent: 'space-between', alignItems: 'center' },
  teamText: { color: '#fff', fontWeight: '600', width: '40%', textAlign: 'right' },
  vsBox: { backgroundColor: '#0b0f19', padding: 6, borderRadius: 8, minWidth: 40, alignItems: 'center' },
  vsText: { color: '#10b981', fontWeight: 'bold' },
  emptyText: { color: '#64748b', textAlign: 'center', marginTop: 10 },
  tipRow: { backgroundColor: '#1e293b', padding: 15, borderRadius: 12, marginBottom: 10, borderWidth: 1, borderColor: '#334155' },
  navBar: { flexDirection: 'row', backgroundColor: '#151f32', padding: 15, borderTopWidth: 1, borderColor: '#1e293b' },
  navItem: { flex: 1, alignItems: 'center' },
  navText: { color: '#64748b', fontWeight: 'bold' },
  navTextActive: { color: '#10b981' }
});
